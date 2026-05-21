import Foundation
import WebKit
import SwiftUI

@MainActor
final class BrowserDevToolsService: NSObject, ObservableObject {
    // MARK: - Console
    @Published var entries: [BrowserConsoleEntry] = []
    @Published var selectedTab: DevToolsTab = .console

    // MARK: - Elements
    @Published var domTree: BrowserDOMNode? = nil
    @Published var isDOMLoading: Bool = false
    @Published var isInspecting: Bool = false
    @Published var selectedDOMNodeId: UUID? = nil
    var inspectedTag: String?
    var inspectedNodeId: String?

    // MARK: - Network
    @Published var networkEntries: [BrowserNetworkEntry] = []
    @Published var selectedNetworkEntry: BrowserNetworkEntry? = nil

    // MARK: - Storage
    @Published var storageEntries: [BrowserStorageEntry] = []
    @Published var isStorageLoading: Bool = false

    weak var webView: WKWebView?

    // MARK: - Scripts

    private let consoleScript: WKUserScript = {
        let source = """
        (function() {
            if (window.__codniaConsoleInjected) return;
            window.__codniaConsoleInjected = true;

            var levels = ['log', 'info', 'warn', 'error'];
            levels.forEach(function(level) {
                var original = console[level].bind(console);
                console[level] = function() {
                    var args = Array.prototype.slice.call(arguments);
                    original.apply(console, args);
                    try {
                        var serialized = args.map(function(a) {
                            try {
                                if (a === null) return 'null';
                                if (a === undefined) return 'undefined';
                                if (typeof a === 'object' && a !== null && a.tagName) {
                                    return '<' + a.tagName.toLowerCase() + (a.id ? '#' + a.id : '') + '>';
                                }
                                if (typeof a === 'object') return JSON.stringify(a, null, 2);
                                return String(a);
                            } catch(e) { return String(a); }
                        });
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
                            message: serialized.join(' '),
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
                    children: children
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
                    var origReadyState = self.onreadystatechange;

                    self.onreadystatechange = function() {
                        if (self.readyState === 4) {
                            sendNetworkEntry({
                                url: self.__url || '',
                                method: self.__method || 'GET',
                                status: self.status,
                                statusText: self.statusText || '',
                                contentType: (self.getResponseHeader('content-type') || ''),
                                duration: performance.now() - (self.__startTime || performance.now()),
                                requestSize: self.__requestSize || 0,
                                responseSize: (self.responseText || '').length,
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

                    return origFetch.apply(this, arguments).then(function(response) {
                        var duration = performance.now() - startTime;
                        var contentType = response.headers.get('content-type') || '';
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

                // localStorage
                try {
                    for (var i = 0; i < localStorage.length; i++) {
                        var key = localStorage.key(i);
                        result.localStorage.push({ key: key, value: localStorage.getItem(key) });
                    }
                } catch(e) {}

                // sessionStorage
                try {
                    for (var i = 0; i < sessionStorage.length; i++) {
                        var key = sessionStorage.key(i);
                        result.sessionStorage.push({ key: key, value: sessionStorage.getItem(key) });
                    }
                } catch(e) {}

                // cookies
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
                return {
                    tag: (el.tagName || 'unknown').toLowerCase(),
                    id: el.id || '',
                    classes: (el.className && typeof el.className === 'string') ? el.className : ''
                };
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
                    window.webkit.messageHandlers.inspectHandler.postMessage(getNodeInfo(e.target));
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

    // MARK: - Injection

    func injectScripts(into config: WKWebViewConfiguration) {
        let controller = config.userContentController
        controller.addUserScript(consoleScript)
        controller.addUserScript(domScript)
        controller.addUserScript(networkScript)
        controller.addUserScript(storageScript)
        controller.addUserScript(inspectScript)
        controller.add(self, name: "consoleHandler")
        controller.add(self, name: "domHandler")
        controller.add(self, name: "networkHandler")
        controller.add(self, name: "storageHandler")
        controller.add(self, name: "inspectHandler")
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

    // MARK: - Network

    func clearNetwork() {
        networkEntries.removeAll()
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

    // MARK: - Tabs

    enum DevToolsTab: String, CaseIterable {
        case console = "Console"
        case elements = "Elements"
        case network = "Network"
        case storage = "Storage"
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
        case "networkHandler":
            handleNetworkMessage(body)
        case "storageHandler":
            handleStorageMessage(body)
        case "inspectHandler":
            handleInspectMessage(body)
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
        Task { @MainActor in
            let entry = BrowserConsoleEntry(level: level, message: msg, stack: stack, elementInfo: elementInfo)
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

        let entry = BrowserNetworkEntry(
            id: UUID(), url: url, method: method, status: status,
            statusText: statusText, contentType: contentType,
            duration: duration, requestHeaders: [:], responseHeaders: [:],
            requestSize: requestSize, responseSize: responseSize,
            timestamp: Date(timeIntervalSince1970: timestamp / 1000)
        )
        Task { @MainActor in
            self.networkEntries.insert(entry, at: 0)
        }
    }

    private nonisolated func handleInspectMessage(_ body: Any) {
        guard let dict = body as? [String: String],
              let tag = dict["tag"],
              let nodeId = dict["id"] else { return }
        Task { @MainActor in
            self.isInspecting = false
            self.selectedDOMNodeId = nil
            self.refreshDOM()
            // After DOM loads, findAndMark will match by tag+id
            self.inspectedTag = tag
            self.inspectedNodeId = nodeId
        }
    }

    private nonisolated func handleStorageMessage(_ body: Any) {
        guard let dict = body as? [String: Any],
              let data = dict["data"] as? [String: Any] else { return }
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
}
