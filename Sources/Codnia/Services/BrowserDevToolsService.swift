import Foundation
import WebKit
import SwiftUI

@MainActor
final class BrowserDevToolsService: NSObject, ObservableObject {
    // MARK: - Console
    @Published var entries: [BrowserConsoleEntry] = []
    @Published var selectedTab: DevToolsTab = .console
    @Published var consoleFilter: ConsoleFilter = .all
    @Published var preserveConsoleLog: Bool = false
    @Published var showRelativeTimestamps: Bool = false

    enum ConsoleFilter: String, CaseIterable {
        case all = "All"
        case log = "Log"
        case info = "Info"
        case warn = "Warn"
        case error = "Error"

        var level: BrowserConsoleEntry.Level? {
            switch self {
            case .all: return nil
            case .log: return .log
            case .info: return .info
            case .warn: return .warn
            case .error: return .error
            }
        }
    }

    var filteredEntries: [BrowserConsoleEntry] {
        if consoleFilter == .all { return entries }
        return entries.filter { $0.level == consoleFilter.level }
    }

    // MARK: - Elements
    @Published var domTree: BrowserDOMNode? = nil
    @Published var isDOMLoading: Bool = false
    @Published var isInspecting: Bool = false
    @Published var selectedDOMNodeId: UUID? = nil
    @Published var selectedElementSelector: String? = nil
    var inspectedTag: String?
    var inspectedNodeId: String?

    // MARK: - Styles
    @Published var matchedStyles: [BrowserCSSStyle] = []
    @Published var computedStyle: BrowserComputedStyle? = nil
    @Published var isStylesLoading: Bool = false

    // MARK: - Network
    @Published var networkEntries: [BrowserNetworkEntry] = []
    @Published var selectedNetworkEntry: BrowserNetworkEntry? = nil
    @Published var selectedNetworkDetailTab: NetworkDetailTab = .headers
    @Published var networkFilter: NetworkFilter = .all
    @Published var networkFilterText: String = ""
    @Published var preserveNetworkLog: Bool = false

    enum NetworkDetailTab: String, CaseIterable {
        case headers = "Headers"
        case request = "Request"
        case response = "Response"
        case timing = "Timing"
    }

    enum NetworkFilter: String, CaseIterable {
        case all = "All"
        case xhr = "XHR"
        case js = "JS"
        case css = "CSS"
        case img = "Img"
        case doc = "Doc"
        case font = "Font"
        case media = "Media"
        case other = "Other"

        func matches(_ entry: BrowserNetworkEntry) -> Bool {
            switch self {
            case .all: return true
            case .xhr: return entry.method == "XHR" || entry.isXHR
            case .js: return (entry.contentType?.contains("javascript") ?? false) || entry.url.hasSuffix(".js")
            case .css: return (entry.contentType?.contains("css") ?? false) || entry.url.hasSuffix(".css")
            case .img: return entry.contentType?.hasPrefix("image/") == true
            case .doc: return (entry.contentType?.contains("html") ?? false)
            case .font: return (entry.contentType?.contains("font") ?? false) || entry.url.contains(".woff")
            case .media: return entry.contentType?.hasPrefix("video/") == true || entry.contentType?.hasPrefix("audio/") == true
            case .other:
                return !Self.matchesAnyFilter(entry)
            }
        }

        private static func matchesAnyFilter(_ entry: BrowserNetworkEntry) -> Bool {
            for filter in Self.allCases {
                switch filter {
                case .all, .other: continue
                case .xhr: if entry.method == "XHR" || entry.isXHR { return true }
                case .js: if (entry.contentType?.contains("javascript") ?? false) || entry.url.hasSuffix(".js") { return true }
                case .css: if (entry.contentType?.contains("css") ?? false) || entry.url.hasSuffix(".css") { return true }
                case .img: if entry.contentType?.hasPrefix("image/") == true { return true }
                case .doc: if entry.contentType?.contains("html") == true { return true }
                case .font: if (entry.contentType?.contains("font") ?? false) || entry.url.contains(".woff") { return true }
                case .media: if entry.contentType?.hasPrefix("video/") == true || entry.contentType?.hasPrefix("audio/") == true { return true }
                }
            }
            return false
        }
    }

    var filteredNetworkEntries: [BrowserNetworkEntry] {
        var result = networkEntries
        if networkFilter != .all {
            result = result.filter { networkFilter.matches($0) }
        }
        if !networkFilterText.isEmpty {
            result = result.filter { $0.url.localizedCaseInsensitiveContains(networkFilterText) }
        }
        return result
    }

    // MARK: - Storage
    @Published var storageEntries: [BrowserStorageEntry] = []
    @Published var isStorageLoading: Bool = false

    // MARK: - Sources
    @Published var resources: [BrowserResourceEntry] = []

    // MARK: - Application
    @Published var manifestInfo: BrowserManifestInfo?
    @Published var serviceWorkerInfo: BrowserServiceWorkerInfo?
    @Published var cacheStorage: [BrowserCacheEntry] = []
    @Published var isAppLoading: Bool = false

    // MARK: - Docking
    @Published var dockingPosition: DockingPosition = .bottom
    @Published var devToolsWidth: CGFloat = 400
    @Published var isFloating: Bool = false

    enum DockingPosition: String, CaseIterable {
        case bottom = "Bottom"
        case right = "Right"
        case left = "Left"
    }

    weak var webView: WKWebView?

    // MARK: - Scripts

    private let consoleScript: WKUserScript = {
        let source = """
        (function() {
            if (window.__codniaConsoleInjected) return;
            window.__codniaConsoleInjected = true;

            window.__codniaConsoleObjectMap = {};
            window.__codniaObjectCounter = 0;

            function serializeArg(a) {
                try {
                    if (a === null) return { type: 'null', value: 'null' };
                    if (a === undefined) return { type: 'undefined', value: 'undefined' };
                    if (typeof a === 'object' && a !== null && a.tagName) {
                        return { type: 'element', value: '<' + a.tagName.toLowerCase() + (a.id ? '#' + a.id : '') + '>' };
                    }
                    if (typeof a === 'object') {
                        var id = ++window.__codniaObjectCounter;
                        window.__codniaConsoleObjectMap[id] = a;
                        return { type: 'object', value: JSON.stringify(a, null, 2), objectId: id, objectKeys: Object.keys(a) };
                    }
                    return { type: 'string', value: String(a) };
                } catch(e) { return { type: 'string', value: String(a) }; }
            }

            var levels = ['log', 'info', 'warn', 'error'];
            levels.forEach(function(level) {
                var original = console[level].bind(console);
                console[level] = function() {
                    var args = Array.prototype.slice.call(arguments);
                    original.apply(console, args);
                    try {
                        var serialized = args.map(serializeArg);
                        var elementInfo = null;
                        for (var i = 0; i < args.length; i++) {
                            var a = args[i];
                            if (a && typeof a === 'object' && a.tagName) {
                                elementInfo = {
                                    tag: a.tagName.toLowerCase(),
                                    id: a.id || '',
                                    classes: (a.className && typeof a.className === 'string') ? a.className : ''
                                };
                                break;
                            }
                        }
                        window.webkit.messageHandlers.consoleHandler.postMessage({
                            level: level,
                            args: serialized,
                            message: serialized.map(function(s) { return s.value; }).join(' '),
                            timestamp: Date.now(),
                            stack: new Error().stack || null,
                            element: elementInfo
                        });
                    } catch(e) {}
                };
            });

            window.onerror = function(msg, source, line, col, error) {
                try {
                    window.webkit.messageHandlers.consoleHandler.postMessage({
                        level: 'error',
                        message: msg + ' (' + (source || 'unknown') + ':' + line + ':' + col + ')',
                        timestamp: Date.now(),
                        stack: error && error.stack ? error.stack : null
                    });
                } catch(e) {}
                return false;
            };

            window.onunhandledrejection = function(event) {
                try {
                    var reason = event.reason;
                    window.webkit.messageHandlers.consoleHandler.postMessage({
                        level: 'error',
                        message: 'Unhandled Promise Rejection: ' + (reason && reason.message ? reason.message : String(reason)),
                        timestamp: Date.now(),
                        stack: reason && reason.stack ? reason.stack : null
                    });
                } catch(e) {}
            };

            window.__codniaGetObject = function(objectId) {
                var obj = window.__codniaConsoleObjectMap[objectId];
                if (!obj) return 'Object not found';
                try {
                    return JSON.stringify(obj, null, 2);
                } catch(e) {
                    return String(obj);
                }
            };
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }()

    private let domScript: WKUserScript = {
        let source = """
        (function() {
            if (window.__codniaDOMInjected) return;
            window.__codniaDOMInjected = true;

            function buildDOMNode(node, depth) {
                if (!node || depth > 20) return null;

                if (node.nodeType === 3) {
                    var text = (node.textContent || '').trim();
                    if (!text) return null;
                    return { tag: '#text', text: text.substring(0, 200) };
                }

                if (node.nodeType !== 1) return null;

                var attrs = {};
                for (var i = 0; i < (node.attributes || []).length; i++) {
                    var a = node.attributes[i];
                    attrs[a.name] = a.value;
                }

                var children = [];
                var child = node.firstChild;
                while (child) {
                    var c = buildDOMNode(child, depth + 1);
                    if (c) children.push(c);
                    child = child.nextSibling;
                }

                return {
                    tag: (node.tagName || 'unknown').toLowerCase(),
                    id: node.id || '',
                    classes: (node.className && typeof node.className === 'string') ? node.className : '',
                    attributes: attrs,
                    children: children,
                    innerText: node.innerText ? node.innerText.substring(0, 500) : ''
                };
            }

            window.__codniaRequestDOM = function() {
                var root = document.documentElement || document.body;
                var tree = buildDOMNode(root, 0);
                try {
                    window.webkit.messageHandlers.domHandler.postMessage({ tree: tree });
                } catch(e) {}
            };

            window.__codniaHighlightElement = function(selector) {
                var el;
                try { el = document.querySelector(selector); } catch(e) {}
                if (!el) return;
                el.scrollIntoView({ behavior: 'smooth', block: 'center' });
                el.style.outline = '2px solid rgba(59, 130, 246, 0.8)';
                el.style.outlineOffset = '2px';
                setTimeout(function() {
                    el.style.outline = '';
                    el.style.outlineOffset = '';
                }, 2000);
            };
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }()

    private let stylesScript: WKUserScript = {
        let source = """
        (function() {
            if (window.__codniaStylesInjected) return;
            window.__codniaStylesInjected = true;

            function parseStyleText(cssText) {
                var props = {};
                cssText.split(';').forEach(function(decl) {
                    var colonIdx = decl.indexOf(':');
                    if (colonIdx > 0) {
                        var name = decl.substring(0, colonIdx).trim();
                        var value = decl.substring(colonIdx + 1).trim();
                        if (name && value) props[name] = value;
                    }
                });
                return props;
            }

            window.__codniaRequestStyles = function(selector) {
                var el;
                try { el = document.querySelector(selector); } catch(e) {}
                if (!el) {
                    window.webkit.messageHandlers.styleHandler.postMessage({ error: 'Element not found: ' + selector });
                    return;
                }

                // 1. Matched CSS rules
                var matchedRules = [];
                try {
                    for (var i = 0; i < document.styleSheets.length; i++) {
                        var sheet = document.styleSheets[i];
                        try {
                            var rules = sheet.cssRules || sheet.rules;
                            if (!rules) continue;
                            for (var j = 0; j < rules.length; j++) {
                                var rule = rules[j];
                                if (rule.type === 1 && rule.selectorText) {
                                    try {
                                        if (el.matches(rule.selectorText)) {
                                            matchedRules.push({
                                                selector: rule.selectorText,
                                                cssText: rule.style.cssText,
                                                properties: parseStyleText(rule.style.cssText),
                                                source: sheet.href || 'inline',
                                                index: j
                                            });
                                        }
                                    } catch(e) {}
                                }
                            }
                        } catch(e) {}
                    }
                } catch(e) {}

                // 2. Computed style
                var computed = window.getComputedStyle(el);
                var computedProps = {};
                var length = computed.length;
                for (var k = 0; k < length; k++) {
                    var name = computed[k];
                    computedProps[name] = computed.getPropertyValue(name);
                }

                // 3. Box model
                var rect = el.getBoundingClientRect();
                var cs = computed;
                var box = {
                    margin: { top: cs.marginTop, right: cs.marginRight, bottom: cs.marginBottom, left: cs.marginLeft },
                    border: { top: cs.borderTopWidth, right: cs.borderRightWidth, bottom: cs.borderBottomWidth, left: cs.borderLeftWidth },
                    padding: { top: cs.paddingTop, right: cs.paddingRight, bottom: cs.paddingBottom, left: cs.paddingLeft },
                    content: { width: rect.width, height: rect.height }
                };

                window.webkit.messageHandlers.styleHandler.postMessage({
                    matched: matchedRules,
                    computed: computedProps,
                    box: box
                });
            };
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }()

    private let attributeEditScript: WKUserScript = {
        let source = """
        (function() {
            if (window.__codniaAttrEditInjected) return;
            window.__codniaAttrEditInjected = true;

            window.__codniaSetAttribute = function(selector, attrName, attrValue) {
                var el;
                try { el = document.querySelector(selector); } catch(e) {}
                if (!el) return false;
                try {
                    if (attrValue === null || attrValue === '') {
                        el.removeAttribute(attrName);
                    } else {
                        el.setAttribute(attrName, attrValue);
                    }
                    return true;
                } catch(e) { return false; }
            };

            window.__codniaRemoveAttribute = function(selector, attrName) {
                var el;
                try { el = document.querySelector(selector); } catch(e) {}
                if (!el) return false;
                try {
                    el.removeAttribute(attrName);
                    return true;
                } catch(e) { return false; }
            };

            window.__codniaSetElementText = function(selector, text) {
                var el;
                try { el = document.querySelector(selector); } catch(e) {}
                if (!el) return false;
                try {
                    if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
                        el.value = text;
                    } else {
                        el.textContent = text;
                    }
                    return true;
                } catch(e) { return false; }
            };
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }()

    private let networkScript: WKUserScript = {
        let source = """
        (function() {
            if (window.__codniaNetworkInjected) return;
            window.__codniaNetworkInjected = true;

            function sendNetworkEntry(data) {
                try {
                    window.webkit.messageHandlers.networkHandler.postMessage(data);
                } catch(e) {}
            }

            function getResponseHeaders(xhr) {
                var headers = {};
                var all = xhr.getAllResponseHeaders();
                if (all) {
                    all.split('\\\\r\\\\n').forEach(function(line) {
                        var idx = line.indexOf(': ');
                        if (idx > 0) {
                            headers[line.substring(0, idx).toLowerCase()] = line.substring(idx + 2);
                        }
                    });
                }
                return headers;
            }

            // Intercept XMLHttpRequest
            (function() {
                var XHR = XMLHttpRequest.prototype;
                var origOpen = XHR.open;
                var origSend = XHR.send;

                XHR.open = function(method, url) {
                    this.__method = (method || 'GET').toUpperCase();
                    this.__url = (typeof url === 'string') ? url : (url && url.href ? url.href : String(url));
                    this.__startTime = performance.now();
                    return origOpen.apply(this, arguments);
                };

                XHR.send = function(body) {
                    var self = this;
                    self.__requestSize = body ? (typeof body === 'string' ? body.length : 0) : 0;
                    self.__requestBody = body && typeof body === 'string' ? body.substring(0, 10000) : '';
                    var origReadyState = self.onreadystatechange;

                    self.onreadystatechange = function() {
                        if (self.readyState === 4) {
                            var respHeaders = getResponseHeaders(self);
                            sendNetworkEntry({
                                url: self.__url || '',
                                method: self.__method || 'GET',
                                status: self.status,
                                statusText: self.statusText || '',
                                contentType: (self.getResponseHeader('content-type') || ''),
                                duration: performance.now() - (self.__startTime || performance.now()),
                                requestSize: self.__requestSize || 0,
                                responseSize: (self.responseText || '').length,
                                requestHeaders: {},
                                responseHeaders: respHeaders,
                                requestBody: self.__requestBody || '',
                                responseBody: (self.responseText || '').substring(0, 50000),
                                timestamp: Date.now()
                            });
                        }
                        if (origReadyState) {
                            origReadyState.apply(self, arguments);
                        }
                    };
                    return origSend.apply(this, arguments);
                };
            })();

            // Intercept fetch
            var origFetch = window.fetch;
            if (origFetch) {
                window.fetch = function(input, init) {
                    var url = (typeof input === 'string') ? input : (input && input.url ? input.url : String(input));
                    var method = (init && init.method) ? init.method.toUpperCase() : 'GET';
                    var startTime = performance.now();
                    var reqSize = init && init.body ? (typeof init.body === 'string' ? init.body.length : 0) : 0;
                    var reqBody = init && typeof init.body === 'string' ? init.body.substring(0, 10000) : '';

                    return origFetch.apply(this, arguments).then(function(response) {
                        var duration = performance.now() - startTime;
                        var contentType = response.headers.get('content-type') || '';
                        var respHeaders = {};
                        response.headers.forEach(function(v, k) { respHeaders[k] = v; });
                        var clone = response.clone();
                        clone.text().then(function(body) {
                            sendNetworkEntry({
                                url: url,
                                method: method,
                                status: response.status,
                                statusText: response.statusText,
                                contentType: contentType,
                                duration: duration,
                                requestSize: reqSize,
                                responseSize: body.length,
                                requestHeaders: {},
                                responseHeaders: respHeaders,
                                requestBody: reqBody,
                                responseBody: body.substring(0, 50000),
                                timestamp: Date.now()
                            });
                        }).catch(function() {
                            sendNetworkEntry({
                                url: url,
                                method: method,
                                status: response.status,
                                statusText: response.statusText,
                                contentType: contentType,
                                duration: duration,
                                requestSize: reqSize,
                                responseSize: 0,
                                requestHeaders: {},
                                responseHeaders: respHeaders,
                                requestBody: reqBody,
                                responseBody: '',
                                timestamp: Date.now()
                            });
                        });
                        return response;
                    }).catch(function(error) {
                        sendNetworkEntry({
                            url: url,
                            method: method,
                            status: 0,
                            statusText: error.message || 'Network Error',
                            duration: performance.now() - startTime,
                            timestamp: Date.now()
                        });
                        throw error;
                    });
                };
            }

            // Performance API timing
            window.__codniaGetResourceTimings = function() {
                try {
                    var entries = performance.getEntriesByType('resource');
                    return entries.map(function(e) {
                        return {
                            name: e.name,
                            initiatorType: e.initiatorType,
                            startTime: e.startTime,
                            duration: e.duration,
                            domainLookupStart: e.domainLookupStart,
                            domainLookupEnd: e.domainLookupEnd,
                            connectStart: e.connectStart,
                            connectEnd: e.connectEnd,
                            secureConnectionStart: e.secureConnectionStart,
                            requestStart: e.requestStart,
                            responseStart: e.responseStart,
                            responseEnd: e.responseEnd
                        };
                    });
                } catch(e) { return []; }
            };
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }()

    private let storageScript: WKUserScript = {
        let source = """
        (function() {
            if (window.__codniaStorageInjected) return;
            window.__codniaStorageInjected = true;

            window.__codniaRequestStorage = function() {
                var result = { localStorage: [], sessionStorage: [], cookies: [] };

                try {
                    for (var i = 0; i < localStorage.length; i++) {
                        var key = localStorage.key(i);
                        result.localStorage.push({ key: key, value: localStorage.getItem(key) });
                    }
                } catch(e) {}

                try {
                    for (var i = 0; i < sessionStorage.length; i++) {
                        var key = sessionStorage.key(i);
                        result.sessionStorage.push({ key: key, value: sessionStorage.getItem(key) });
                    }
                } catch(e) {}

                try {
                    if (document.cookie) {
                        document.cookie.split(';').forEach(function(c) {
                            var parts = c.split('=');
                            if (parts.length >= 1) {
                                var key = (parts.shift() || '').trim();
                                var value = parts.join('=').trim();
                                if (key) result.cookies.push({ key: key, value: value });
                            }
                        });
                    }
                } catch(e) {}

                try {
                    window.webkit.messageHandlers.storageHandler.postMessage({ data: result });
                } catch(e) {}
            };

            window.__codniaSetStorageItem = function(type, key, value) {
                try {
                    if (type === 'localStorage') { localStorage.setItem(key, value); return true; }
                    if (type === 'sessionStorage') { sessionStorage.setItem(key, value); return true; }
                    if (type === 'cookie') { document.cookie = key + '=' + value + '; path=/'; return true; }
                } catch(e) {}
                return false;
            };

            window.__codniaRemoveStorageItem = function(type, key) {
                try {
                    if (type === 'localStorage') { localStorage.removeItem(key); return true; }
                    if (type === 'sessionStorage') { sessionStorage.removeItem(key); return true; }
                    if (type === 'cookie') { document.cookie = key + '=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;'; return true; }
                } catch(e) {}
                return false;
            };

            window.__codniaClearStorage = function(type) {
                try {
                    if (type === 'localStorage') { localStorage.clear(); return true; }
                    if (type === 'sessionStorage') { sessionStorage.clear(); return true; }
                    if (type === 'cookies') {
                        document.cookie.split(';').forEach(function(c) {
                            var eqPos = c.indexOf('=');
                            var name = eqPos > -1 ? c.substring(0, eqPos).trim() : c.trim();
                            document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
                        });
                        return true;
                    }
                } catch(e) {}
                return false;
            };

            window.__codniaRequestIndexedDB = function() {
                var dbs = {};
                try {
                    if (indexedDB) {
                        indexedDB.databases().then(function(dbList) {
                            dbs = dbList;
                            window.webkit.messageHandlers.storageHandler.postMessage({ indexedDB: dbList });
                        }).catch(function() {});
                    }
                } catch(e) {}
            };
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }()

    private let inspectScript: WKUserScript = {
        let source = """
        (function() {
            if (window.__codniaInspectInjected) return;
            window.__codniaInspectInjected = true;

            var inspectEnabled = false;
            var hoveredEl = null;
            var overlay = null;

            function createOverlay() {
                overlay = document.createElement('div');
                overlay.style.cssText = 'position:fixed;pointer-events:none;z-index:2147483647;border:2px solid rgba(59,130,246,0.8);background:rgba(59,130,246,0.08);transition:all 0.05s;display:none;';
                document.body.appendChild(overlay);
            }

            function moveOverlay(el) {
                if (!overlay) return;
                var rect = el.getBoundingClientRect();
                overlay.style.display = 'block';
                overlay.style.top = (rect.top + window.scrollY) + 'px';
                overlay.style.left = (rect.left + window.scrollX) + 'px';
                overlay.style.width = rect.width + 'px';
                overlay.style.height = rect.height + 'px';
            }

            function getNodeInfo(el) {
                var selector = el.tagName.toLowerCase();
                if (el.id) selector += '#' + el.id;
                return {
                    tag: (el.tagName || 'unknown').toLowerCase(),
                    id: el.id || '',
                    classes: (el.className && typeof el.className === 'string') ? el.className : '',
                    selector: selector
                };
            }

            function getUniqueSelector(el) {
                if (el.id) return '#' + el.id;
                var path = [];
                while (el && el.nodeType === 1) {
                    var selector = el.tagName.toLowerCase();
                    if (el.id) { path.unshift('#' + el.id); break; }
                    var sib = el.parentElement ? Array.from(el.parentElement.children).filter(function(c) { return c.tagName === el.tagName; }) : [];
                    if (sib.length > 1) {
                        var idx = sib.indexOf(el) + 1;
                        selector += ':nth-child(' + idx + ')';
                    }
                    path.unshift(selector);
                    el = el.parentElement;
                }
                return path.join(' > ');
            }

            document.addEventListener('mousemove', function(e) {
                if (!inspectEnabled) return;
                var el = e.target;
                if (el === overlay || el === hoveredEl) return;
                hoveredEl = el;
                moveOverlay(el);
            }, true);

            document.addEventListener('click', function(e) {
                if (!inspectEnabled) return;
                e.preventDefault();
                e.stopPropagation();
                inspectEnabled = false;
                if (overlay) overlay.style.display = 'none';
                try {
                    var info = getNodeInfo(e.target);
                    info.selector = getUniqueSelector(e.target);
                    window.webkit.messageHandlers.inspectHandler.postMessage(info);
                } catch(ex) {}
            }, true);

            window.__codniaStartInspect = function() {
                inspectEnabled = true;
                if (!overlay) createOverlay();
            };

            window.__codniaStopInspect = function() {
                inspectEnabled = false;
                if (overlay) overlay.style.display = 'none';
            };
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }()

    private let sourcesScript: WKUserScript = {
        let source = """
        (function() {
            if (window.__codniaSourcesInjected) return;
            window.__codniaSourcesInjected = true;

            window.__codniaRequestSources = function() {
                var resources = performance.getEntriesByType('resource');
                var results = [];
                for (var i = 0; i < resources.length; i++) {
                    var r = resources[i];
                    try {
                        var url = r.name;
                        var domain = '';
                        try { domain = new URL(url).hostname; } catch(e) {}
                        results.push({
                            url: url,
                            domain: domain,
                            mimeType: r.initiatorType || '',
                            statusCode: 0,
                            contentLength: r.transferSize || 0
                        });
                    } catch(e) {}
                }
                try {
                    window.webkit.messageHandlers.sourcesHandler.postMessage({ resources: results });
                } catch(e) {}
            };
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }()

    private let applicationScript: WKUserScript = {
        let source = """
        (function() {
            if (window.__codniaAppInjected) return;
            window.__codniaAppInjected = true;

            window.__codniaRequestAppInfo = function() {
                var result = { manifest: null, sw: null, caches: [] };

                // Manifest
                var links = document.querySelectorAll('link[rel="manifest"]');
                if (links.length > 0) {
                    var manifestURL = links[0].getAttribute('href');
                    if (manifestURL) {
                        var absURL = new URL(manifestURL, location.href).href;
                        result.manifest = { url: absURL };
                        fetch(absURL).then(function(res) { return res.json(); }).then(function(data) {
                            result.manifest = {
                                url: absURL,
                                name: data.name || '',
                                shortName: data.short_name || '',
                                description: data.description || '',
                                startURL: data.start_url || '',
                                display: data.display || '',
                                themeColor: data.theme_color || '',
                                backgroundColor: data.background_color || '',
                                icons: (data.icons || []).map(function(ic) {
                                    return { src: ic.src, sizes: ic.sizes || '', type: ic.type || '' };
                                }),
                                json: JSON.stringify(data, null, 2)
                            };
                            window.webkit.messageHandlers.appHandler.postMessage({ manifest: result.manifest });
                        }).catch(function() {
                            window.webkit.messageHandlers.appHandler.postMessage({ manifest: { url: absURL, error: true } });
                        });
                    }
                }

                // Service Worker
                if (navigator.serviceWorker && navigator.serviceWorker.controller) {
                    var sw = navigator.serviceWorker.controller;
                    result.sw = {
                        scriptURL: sw.scriptURL || '',
                        state: sw.state || '',
                        isActive: sw.state === 'activated'
                    };
                }

                // Cache Storage
                if (typeof caches !== 'undefined') {
                    caches.keys().then(function(names) {
                        var cacheResults = [];
                        names.forEach(function(name) {
                            cacheResults.push({ name: name, size: 0 });
                        });
                        result.caches = cacheResults;
                        window.webkit.messageHandlers.appHandler.postMessage({ caches: cacheResults });
                    }).catch(function() {});
                }

                // Send SW info immediately
                if (result.sw) {
                    window.webkit.messageHandlers.appHandler.postMessage({ sw: result.sw });
                }

                // If no manifest link, send empty
                if (!result.manifest) {
                    window.webkit.messageHandlers.appHandler.postMessage({ manifest: null });
                }
            };

            window.__codniaClearBrowserData = function(types) {
                try {
                    if (types.indexOf('localStorage') >= 0) localStorage.clear();
                    if (types.indexOf('sessionStorage') >= 0) sessionStorage.clear();
                    if (types.indexOf('cookies') >= 0) {
                        document.cookie.split(';').forEach(function(c) {
                            var eqPos = c.indexOf('=');
                            var name = eqPos > -1 ? c.substring(0, eqPos).trim() : c.trim();
                            document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
                        });
                    }
                    if (types.indexOf('cache') >= 0 && typeof caches !== 'undefined') {
                        caches.keys().then(function(names) {
                            names.forEach(function(name) { caches.delete(name); });
                        });
                    }
                    return true;
                } catch(e) { return false; }
            };
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }()

    // MARK: - Injection

    func injectScripts(into config: WKWebViewConfiguration) {
        let controller = config.userContentController
        controller.addUserScript(consoleScript)
        controller.addUserScript(domScript)
        controller.addUserScript(stylesScript)
        controller.addUserScript(attributeEditScript)
        controller.addUserScript(networkScript)
        controller.addUserScript(storageScript)
        controller.addUserScript(inspectScript)
        controller.addUserScript(sourcesScript)
        controller.addUserScript(applicationScript)
        controller.add(self, name: "consoleHandler")
        controller.add(self, name: "domHandler")
        controller.add(self, name: "styleHandler")
        controller.add(self, name: "attrEditHandler")
        controller.add(self, name: "networkHandler")
        controller.add(self, name: "storageHandler")
        controller.add(self, name: "inspectHandler")
        controller.add(self, name: "sourcesHandler")
        controller.add(self, name: "appHandler")
    }

    // MARK: - Console

    func evaluateJS(_ code: String) {
        guard let webView = webView else { return }
        webView.evaluateJavaScript(code) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                self.addEntry(level: .error, message: "JS Error: \(error.localizedDescription)")
            } else if let result = result {
                self.addEntry(level: .log, message: "→ \(String(describing: result))")
            } else {
                self.addEntry(level: .info, message: "→ undefined")
            }
        }
    }

    func addEntry(level: BrowserConsoleEntry.Level, message: String, stack: String? = nil) {
        let entry = BrowserConsoleEntry(level: level, message: message, stack: stack)
        entries.append(entry)
    }

    func clearConsole() {
        entries.removeAll()
    }

    func getConsoleObject(_ objectId: Int) {
        guard let webView = webView else { return }
        webView.evaluateJavaScript("window.__codniaGetObject ? window.__codniaGetObject(\(objectId)) : null") { [weak self] result, error in
            guard let self = self else { return }
            if let json = result as? String {
                self.addEntry(level: .log, message: json)
            }
        }
    }

    // MARK: - Elements

    func refreshDOM() {
        guard let webView = webView else { return }
        isDOMLoading = true
        webView.evaluateJavaScript("window.__codniaRequestDOM ? (window.__codniaRequestDOM(), true) : false") { [weak self] result, error in
            if let error = error {
                self?.isDOMLoading = false
                self?.addEntry(level: .error, message: "DOM refresh error: \(error.localizedDescription)")
            } else if let ok = result as? Bool, !ok {
                self?.isDOMLoading = false
            }
        }
    }

    func highlightElement(_ node: BrowserDOMNode) {
        guard let webView = webView else { return }
        let selector: String
        if !node.nodeId.isEmpty {
            let safeId = node.nodeId.replacingOccurrences(of: "'", with: "\\'")
            selector = "#\(safeId)"
        } else {
            selector = node.tag
        }
        let escaped = selector.replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("window.__codniaHighlightElement ? (window.__codniaHighlightElement('\(escaped)'), true) : false")
    }

    func navigateToElement(tag: String, nodeId: String, classes: String) {
        selectedTab = .elements
        inspectedTag = tag
        inspectedNodeId = nodeId
        refreshDOM()
        if !nodeId.isEmpty {
            let safeId = nodeId.replacingOccurrences(of: "'", with: "\\'")
            webView?.evaluateJavaScript("window.__codniaHighlightElement ? window.__codniaHighlightElement('#\(safeId)') : false")
        } else {
            webView?.evaluateJavaScript("window.__codniaHighlightElement ? window.__codniaHighlightElement('\(tag)') : false")
        }
    }

    func toggleInspectMode() {
        guard let webView = webView else { return }
        isInspecting.toggle()
        if isInspecting {
            webView.evaluateJavaScript("window.__codniaStartInspect ? (window.__codniaStartInspect(), true) : false")
        } else {
            webView.evaluateJavaScript("window.__codniaStopInspect ? (window.__codniaStopInspect(), true) : false")
        }
    }

    // MARK: - Styles

    func refreshStylesForSelected() {
        guard let webView = webView, let selector = selectedElementSelector else { return }
        isStylesLoading = true
        let escaped = selector.replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("window.__codniaRequestStyles ? (window.__codniaRequestStyles('\(escaped)'), true) : false") { [weak self] result, error in
            if let error = error {
                self?.isStylesLoading = false
            } else if let ok = result as? Bool, !ok {
                self?.isStylesLoading = false
            }
        }
    }

    // MARK: - Attribute Editing

    func setAttribute(selector: String, name: String, value: String) {
        guard let webView = webView else { return }
        let escapedSelector = selector.replacingOccurrences(of: "'", with: "\\'")
        let escapedName = name.replacingOccurrences(of: "'", with: "\\'")
        let escapedValue = value.replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("window.__codniaSetAttribute ? window.__codniaSetAttribute('\(escapedSelector)', '\(escapedName)', '\(escapedValue)') : false")
    }

    func removeAttribute(selector: String, name: String) {
        guard let webView = webView else { return }
        let escapedSelector = selector.replacingOccurrences(of: "'", with: "\\'")
        let escapedName = name.replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("window.__codniaRemoveAttribute ? window.__codniaRemoveAttribute('\(escapedSelector)', '\(escapedName)') : false")
    }

    // MARK: - Network

    func clearNetwork() {
        networkEntries.removeAll()
    }

    func getResourceTimings() {
        guard let webView = webView else { return }
        webView.evaluateJavaScript("window.__codniaGetResourceTimings ? window.__codniaGetResourceTimings() : []")
    }

    // MARK: - Storage

    func refreshStorage() {
        guard let webView = webView else { return }
        isStorageLoading = true
        webView.evaluateJavaScript("window.__codniaRequestStorage ? (window.__codniaRequestStorage(), true) : false") { [weak self] result, error in
            if let error = error {
                self?.isStorageLoading = false
                self?.addEntry(level: .error, message: "Storage refresh error: \(error.localizedDescription)")
            } else if let ok = result as? Bool, !ok {
                self?.isStorageLoading = false
            }
        }
    }

    func setStorageItem(type: String, key: String, value: String) {
        guard let webView = webView else { return }
        let escapedKey = key.replacingOccurrences(of: "'", with: "\\'")
        let escapedValue = value.replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("window.__codniaSetStorageItem ? window.__codniaSetStorageItem('\(type)', '\(escapedKey)', '\(escapedValue)') : false") { [weak self] _, _ in
            self?.refreshStorage()
        }
    }

    func removeStorageItem(type: String, key: String) {
        guard let webView = webView else { return }
        let escapedKey = key.replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("window.__codniaRemoveStorageItem ? window.__codniaRemoveStorageItem('\(type)', '\(escapedKey)') : false") { [weak self] _, _ in
            self?.refreshStorage()
        }
    }

    func clearStorage(type: String) {
        guard let webView = webView else { return }
        webView.evaluateJavaScript("window.__codniaClearStorage ? window.__codniaClearStorage('\(type)') : false") { [weak self] _, _ in
            self?.refreshStorage()
        }
    }

    // MARK: - Sources

    func refreshSources() {
        guard let webView = webView else { return }
        webView.evaluateJavaScript("window.__codniaRequestSources ? (window.__codniaRequestSources(), true) : false")
    }

    func addResource(url: String, mimeType: String, statusCode: Int) {
        guard let urlObj = URL(string: url) else { return }
        let domain = urlObj.host ?? ""
        let entry = BrowserResourceEntry(
            id: UUID(), url: url, domain: domain,
            mimeType: mimeType, statusCode: statusCode,
            contentLength: 0
        )
        if !resources.contains(where: { $0.url == url }) {
            resources.append(entry)
        }
    }

    // MARK: - Application

    func refreshApplication() {
        guard let webView = webView else { return }
        isAppLoading = true
        webView.evaluateJavaScript("window.__codniaRequestAppInfo ? (window.__codniaRequestAppInfo(), true) : false") { [weak self] _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self?.isAppLoading = false
            }
        }
    }

    func clearBrowserData(types: [String]) {
        guard let webView = webView else { return }
        let typesJSON = types.map { "\"\($0)\"" }.joined(separator: ",")
        webView.evaluateJavaScript("window.__codniaClearBrowserData ? window.__codniaClearBrowserData([\(typesJSON)]) : false")
    }

    // MARK: - Tabs

    enum DevToolsTab: String, CaseIterable {
        case console = "Console"
        case elements = "Elements"
        case styles = "Styles"
        case computed = "Computed"
        case network = "Network"
        case storage = "Storage"
        case sources = "Sources"
        case application = "Application"
    }
}

// MARK: - WKScriptMessageHandler

extension BrowserDevToolsService: WKScriptMessageHandler {
    nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let name = message.name
        let body = message.body
        switch name {
        case "consoleHandler":
            handleConsoleMessage(body)
        case "domHandler":
            handleDOMMessage(body)
        case "styleHandler":
            handleStyleMessage(body)
        case "attrEditHandler":
            handleAttrEditMessage(body)
        case "networkHandler":
            handleNetworkMessage(body)
        case "storageHandler":
            handleStorageMessage(body)
        case "inspectHandler":
            handleInspectMessage(body)
        case "sourcesHandler":
            handleSourcesMessage(body)
        case "appHandler":
            handleAppMessage(body)
        default:
            break
        }
    }

    private nonisolated func handleConsoleMessage(_ body: Any) {
        guard let dict = body as? [String: Any],
              let levelRaw = dict["level"] as? String,
              let msg = dict["message"] as? String else { return }
        let level = BrowserConsoleEntry.Level(rawValue: levelRaw) ?? .log
        let stack = dict["stack"] as? String
        let elementInfo: BrowserConsoleEntry.ElementInfo?
        if let el = dict["element"] as? [String: String],
           let tag = el["tag"] {
            elementInfo = BrowserConsoleEntry.ElementInfo(
                tag: tag,
                nodeId: el["id"] ?? "",
                classes: el["classes"] ?? ""
            )
        } else {
            elementInfo = nil
        }

        let argsRaw = dict["args"] as? [[String: Any]]

        Task { @MainActor in
            let entry = BrowserConsoleEntry(level: level, message: msg, stack: stack, elementInfo: elementInfo, args: argsRaw)
            self.entries.append(entry)
        }
    }

    private nonisolated func handleDOMMessage(_ body: Any) {
        guard let dict = body as? [String: Any],
              let treeDict = dict["tree"] as? [String: Any],
              let node = BrowserDOMNode.fromJSON(treeDict) else { return }
        Task { @MainActor in
            var result = node
            if let tag = self.inspectedTag, let nid = self.inspectedNodeId {
                if let marked = result.findAndMark(tag: tag, nodeId: nid) {
                    result = marked
                    result.findSelectedId { id in
                        self.selectedDOMNodeId = id
                    }
                }
                self.inspectedTag = nil
                self.inspectedNodeId = nil
            }
            self.domTree = result
            self.isDOMLoading = false
        }
    }

    private nonisolated func handleStyleMessage(_ body: Any) {
        guard let dict = body as? [String: Any] else { return }

        if let error = dict["error"] as? String {
            Task { @MainActor in
                self.isStylesLoading = false
                self.addEntry(level: .error, message: "Styles: \(error)")
            }
            return
        }

        let matchedJSON = dict["matched"] as? [[String: Any]] ?? []
        let computedJSON = dict["computed"] as? [String: String] ?? [:]
        let boxJSON = dict["box"] as? [String: Any]

        var matchedStyles: [BrowserCSSStyle] = []
        for rule in matchedJSON {
            let selector = rule["selector"] as? String ?? ""
            let props = rule["properties"] as? [String: String] ?? [:]
            let source = rule["source"] as? String ?? ""
            matchedStyles.append(BrowserCSSStyle(
                selector: selector,
                properties: props,
                source: source
            ))
        }

        let boxModel = boxJSON.flatMap { BrowserBoxModel.fromJSON($0) }
        let computed = BrowserComputedStyle(properties: computedJSON, boxModel: boxModel)

        Task { @MainActor in
            self.matchedStyles = matchedStyles
            self.computedStyle = computed
            self.isStylesLoading = false
        }
    }

    private nonisolated func handleAttrEditMessage(_ body: Any) {
        guard let result = body as? Bool else { return }
        Task { @MainActor in
            if result {
                self.refreshDOM()
                if let selector = self.selectedElementSelector {
                    self.refreshStylesForSelected()
                }
            }
        }
    }

    private nonisolated func handleNetworkMessage(_ body: Any) {
        guard let dict = body as? [String: Any] else { return }
        let url = dict["url"] as? String ?? ""
        let method = dict["method"] as? String ?? "GET"
        let status = dict["status"] as? Int ?? 0
        let statusText = dict["statusText"] as? String ?? ""
        let contentType = dict["contentType"] as? String
        let duration = dict["duration"] as? Double ?? 0
        let requestSize = dict["requestSize"] as? Int ?? 0
        let responseSize = dict["responseSize"] as? Int ?? 0
        let timestamp = dict["timestamp"] as? Double ?? Date().timeIntervalSince1970 * 1000
        let requestHeaders = dict["requestHeaders"] as? [String: String] ?? [:]
        let responseHeaders = dict["responseHeaders"] as? [String: String] ?? [:]
        let requestBody = dict["requestBody"] as? String
        let responseBody = dict["responseBody"] as? String
        let initiator = dict["initiator"] as? String
        let remoteAddress = dict["remoteAddress"] as? String

        let entry = BrowserNetworkEntry(
            id: UUID(), url: url, method: method, status: status,
            statusText: statusText, contentType: contentType,
            duration: duration, requestHeaders: requestHeaders, responseHeaders: responseHeaders,
            requestSize: requestSize, responseSize: responseSize,
            timestamp: Date(timeIntervalSince1970: timestamp / 1000),
            requestBody: requestBody, responseBody: responseBody,
            initiator: initiator, remoteAddress: remoteAddress,
            timingBreakdown: nil
        )
        Task { @MainActor in
            self.networkEntries.insert(entry, at: 0)
        }
    }

    private nonisolated func handleInspectMessage(_ body: Any) {
        guard let dict = body as? [String: String],
              let tag = dict["tag"],
              let nodeId = dict["id"] else { return }
        let selector = dict["selector"]
        Task { @MainActor in
            self.isInspecting = false
            self.selectedDOMNodeId = nil
            self.selectedElementSelector = selector
            self.refreshDOM()
            self.inspectedTag = tag
            self.inspectedNodeId = nodeId
            // Trigger style fetch for the inspected element
            if let sel = selector {
                self.refreshStylesForSelected()
            }
        }
    }

    private nonisolated func handleStorageMessage(_ body: Any) {
        guard let dict = body as? [String: Any],
              let data = dict["data"] as? [String: Any] else {
            // Check for indexedDB
            if let dbList = body as? [[String: Any]] {
                Task { @MainActor in
                    self.addEntry(level: .info, message: "IndexedDB databases: \(dbList.count)")
                }
            }
            return
        }
        var entries: [BrowserStorageEntry] = []

        if let ls = data["localStorage"] as? [[String: String]] {
            for item in ls {
                if let k = item["key"], let v = item["value"] {
                    entries.append(BrowserStorageEntry(id: UUID(), key: k, value: v, type: .localStorage))
                }
            }
        }
        if let ss = data["sessionStorage"] as? [[String: String]] {
            for item in ss {
                if let k = item["key"], let v = item["value"] {
                    entries.append(BrowserStorageEntry(id: UUID(), key: k, value: v, type: .sessionStorage))
                }
            }
        }
        if let ck = data["cookies"] as? [[String: String]] {
            for item in ck {
                if let k = item["key"], let v = item["value"] {
                    entries.append(BrowserStorageEntry(id: UUID(), key: k, value: v, type: .cookies))
                }
            }
        }

        Task { @MainActor in
            self.storageEntries = entries
            self.isStorageLoading = false
        }
    }

    private nonisolated func handleSourcesMessage(_ body: Any) {
        guard let dict = body as? [String: Any],
              let resourcesJSON = dict["resources"] as? [[String: Any]] else { return }
        var results: [BrowserResourceEntry] = []
        for r in resourcesJSON {
            guard let url = r["url"] as? String else { continue }
            let domain = r["domain"] as? String ?? ""
            let mimeType = r["mimeType"] as? String ?? ""
            let statusCode = r["statusCode"] as? Int ?? 0
            let contentLength = r["contentLength"] as? Int64 ?? 0
            results.append(BrowserResourceEntry(
                id: UUID(), url: url, domain: domain,
                mimeType: mimeType, statusCode: statusCode,
                contentLength: contentLength
            ))
        }
        Task { @MainActor in
            self.resources = results
        }
    }

    private nonisolated func handleAppMessage(_ body: Any) {
        guard let dict = body as? [String: Any] else { return }

        if let manifest = dict["manifest"] as? [String: Any] {
            let info = BrowserManifestInfo(
                name: manifest["name"] as? String,
                shortName: manifest["shortName"] as? String,
                description: manifest["description"] as? String,
                startURL: manifest["startURL"] as? String,
                display: manifest["display"] as? String,
                themeColor: manifest["themeColor"] as? String,
                backgroundColor: manifest["backgroundColor"] as? String,
                icons: (manifest["icons"] as? [[String: Any]])?.map { icon in
                    BrowserManifestInfo.ManifestIcon(
                        src: icon["src"] as? String ?? "",
                        sizes: icon["sizes"] as? String ?? "",
                        type: icon["type"] as? String ?? ""
                    )
                } ?? [],
                json: manifest["json"] as? String ?? ""
            )
            Task { @MainActor in
                self.manifestInfo = info
            }
        }

        if let sw = dict["sw"] as? [String: Any] {
            let info = BrowserServiceWorkerInfo(
                scriptURL: sw["scriptURL"] as? String ?? "",
                state: sw["state"] as? String ?? "",
                isActive: sw["isActive"] as? Bool ?? false
            )
            Task { @MainActor in
                self.serviceWorkerInfo = info
            }
        }

        if let caches = dict["caches"] as? [[String: Any]] {
            var results: [BrowserCacheEntry] = []
            for c in caches {
                let name = c["name"] as? String ?? ""
                let size = c["size"] as? Int64 ?? 0
                results.append(BrowserCacheEntry(id: UUID(), name: name, size: size))
            }
            Task { @MainActor in
                self.cacheStorage = results
                self.isAppLoading = false
            }
        }
    }
}
