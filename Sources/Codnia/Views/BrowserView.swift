import SwiftUI
import WebKit
import AppKit

struct BrowserView: View {
    let tabId: String
    @Binding var urlString: String
    @Binding var pageTitle: String
    var onNavigate: (String) -> Void
    var onClose: () -> Void
    var onPinToLeft: (() -> Void)?
    var onPinToRight: (() -> Void)?
    var onPinToTab: (() -> Void)?

    @EnvironmentObject var appState: AppState

    @State private var isLoading: Bool = false
    @State private var estimatedProgress: Double = 0
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var localURLText: String = ""
    @State private var findVisible: Bool = false
    @State private var zoomLevel: Double = 1.0

    @FocusState private var urlFieldFocused: Bool

    @StateObject private var devToolsService = BrowserDevToolsService()
    @State private var devToolsOpen: Bool = false
    @State private var devToolsHeight: CGFloat = 200
    @State private var devToolsFloatingWindow: NSWindow?
    @State private var floatingWindowDelegateInstance: FloatingWindowDelegate?
    @State private var webViewCoordinator: WebViewCoordinator?
    @State private var currentDownload: BrowserDownload?

    var body: some View {
        ZStack {
            if devToolsOpen && !devToolsService.isFloating {
                switch devToolsService.dockingPosition {
                case .bottom:
                    VStack(spacing: 0) {
                        BrowserToolbarView(
                            devToolsService: devToolsService,
                            localURLText: $localURLText,
                            urlString: $urlString,
                            pageTitle: $pageTitle,
                            isLoading: $isLoading,
                            canGoBack: $canGoBack,
                            canGoForward: $canGoForward,
                            estimatedProgress: $estimatedProgress,
                            findVisible: $findVisible,
                            bookmarkService: appState.bookmarkService,
                            downloadService: appState.downloadService,
                            settings: appState.settings,
                            webViewCoordinator: webViewCoordinator,
                            onClose: onClose,
                            onPinToLeft: onPinToLeft,
                            onPinToRight: onPinToRight,
                            onPinToTab: onPinToTab,
                            urlFieldFocused: $urlFieldFocused
                        )
                        progressBar
                        if findVisible, let coord = webViewCoordinator {
                            BrowserFindBarView(coordinator: coord, isVisible: $findVisible)
                        }
                        webViewRepresentable
                            .frame(maxHeight: .infinity)
                        HorizontalResizableDivider(
                            height: $devToolsHeight,
                            minHeight: 100,
                            maxHeight: 600
                        )
                        BrowserDevToolsView(devToolsService: devToolsService)
                            .frame(height: devToolsHeight)
                    }
                case .right:
                    VStack(spacing: 0) {
                        BrowserToolbarView(
                            devToolsService: devToolsService,
                            localURLText: $localURLText,
                            urlString: $urlString,
                            pageTitle: $pageTitle,
                            isLoading: $isLoading,
                            canGoBack: $canGoBack,
                            canGoForward: $canGoForward,
                            estimatedProgress: $estimatedProgress,
                            findVisible: $findVisible,
                            bookmarkService: appState.bookmarkService,
                            downloadService: appState.downloadService,
                            settings: appState.settings,
                            webViewCoordinator: webViewCoordinator,
                            onClose: onClose,
                            onPinToLeft: onPinToLeft,
                            onPinToRight: onPinToRight,
                            onPinToTab: onPinToTab,
                            urlFieldFocused: $urlFieldFocused
                        )
                        progressBar
                        if findVisible, let coord = webViewCoordinator {
                            BrowserFindBarView(coordinator: coord, isVisible: $findVisible)
                        }
                        HStack(spacing: 0) {
                            webViewRepresentable
                                .frame(maxWidth: .infinity)
                            ResizableDivider(
                                width: $devToolsService.devToolsWidth,
                                minWidth: 200,
                                maxWidth: 800,
                                side: .right
                            )
                            .frame(width: 6)
                            BrowserDevToolsView(devToolsService: devToolsService)
                                .frame(width: devToolsService.devToolsWidth)
                        }
                    }
                case .left:
                    VStack(spacing: 0) {
                        BrowserToolbarView(
                            devToolsService: devToolsService,
                            localURLText: $localURLText,
                            urlString: $urlString,
                            pageTitle: $pageTitle,
                            isLoading: $isLoading,
                            canGoBack: $canGoBack,
                            canGoForward: $canGoForward,
                            estimatedProgress: $estimatedProgress,
                            findVisible: $findVisible,
                            bookmarkService: appState.bookmarkService,
                            downloadService: appState.downloadService,
                            settings: appState.settings,
                            webViewCoordinator: webViewCoordinator,
                            onClose: onClose,
                            onPinToLeft: onPinToLeft,
                            onPinToRight: onPinToRight,
                            onPinToTab: onPinToTab,
                            urlFieldFocused: $urlFieldFocused
                        )
                        progressBar
                        if findVisible, let coord = webViewCoordinator {
                            BrowserFindBarView(coordinator: coord, isVisible: $findVisible)
                        }
                        HStack(spacing: 0) {
                            BrowserDevToolsView(devToolsService: devToolsService)
                                .frame(width: devToolsService.devToolsWidth)
                            ResizableDivider(
                                width: $devToolsService.devToolsWidth,
                                minWidth: 200,
                                maxWidth: 800,
                                side: .left
                            )
                            .frame(width: 6)
                            webViewRepresentable
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            } else {
                VStack(spacing: 0) {
                    BrowserToolbarView(
                        devToolsService: devToolsService,
                        localURLText: $localURLText,
                        urlString: $urlString,
                        pageTitle: $pageTitle,
                        isLoading: $isLoading,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        estimatedProgress: $estimatedProgress,
                        findVisible: $findVisible,
                        bookmarkService: appState.bookmarkService,
                        downloadService: appState.downloadService,
                        settings: appState.settings,
                        webViewCoordinator: webViewCoordinator,
                        onClose: onClose,
                        onPinToLeft: onPinToLeft,
                        onPinToRight: onPinToRight,
                        onPinToTab: onPinToTab,
                        urlFieldFocused: $urlFieldFocused
                    )
                    progressBar
                    if findVisible, let coord = webViewCoordinator {
                        BrowserFindBarView(coordinator: coord, isVisible: $findVisible)
                    }
                    webViewRepresentable
                }
            }
            keyboardShortcuts
        }
        .onChange(of: devToolsService.isFloating) { floating in
            if floating {
                openFloatingDevTools()
            } else {
                closeFloatingDevTools()
            }
        }
        .onChange(of: devToolsService.isOpen) { open in
            devToolsOpen = open
        }
        .onDisappear {
            closeFloatingDevTools()
            if let coord = webViewCoordinator {
                Task {
                    let store = BrowserPersistenceService.shared.dataStore(for: appState.persistenceService.currentWorktreeId)
                    await BrowserPersistenceService.shared.backupCookies(worktreeId: appState.persistenceService.currentWorktreeId, from: store)
                    coord.snapshotStorage(into: appState.persistenceService.currentWorktreeId)
                }
            }
        }
    }

    private func openFloatingDevTools() {
        let delegate = FloatingWindowDelegate(devToolsService: devToolsService)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "DevTools — \(pageTitle)"
        window.center()
        window.contentView = NSHostingView(
            rootView: BrowserDevToolsView(devToolsService: devToolsService)
        )
        window.delegate = delegate
        window.makeKeyAndOrderFront(nil)
        devToolsFloatingWindow = window
        floatingWindowDelegateInstance = delegate
    }

    private func closeFloatingDevTools() {
        devToolsFloatingWindow?.close()
        devToolsFloatingWindow = nil
        floatingWindowDelegateInstance = nil
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.borderLight)
                    .frame(height: 2)
                Rectangle()
                    .fill(Color.accentBlue)
                    .frame(width: geo.size.width * estimatedProgress, height: 2)
                    .animation(.linear(duration: 0.2), value: estimatedProgress)
            }
            .opacity(isLoading ? 1 : 0)
        }
        .frame(height: 2)
    }

    private var webViewRepresentable: some View {
        WebViewRepresentable(
            tabId: tabId,
            urlString: $urlString,
            pageTitle: $pageTitle,
            isLoading: $isLoading,
            estimatedProgress: $estimatedProgress,
            canGoBack: $canGoBack,
            canGoForward: $canGoForward,
            coordinator: $webViewCoordinator,
            devToolsService: devToolsService,
            persistenceService: appState.persistenceService,
            historyService: appState.historyService,
            credentialService: appState.credentialService,
            downloadService: appState.downloadService,
            settings: appState.settings,
            onZoomChange: { newZoom in
                zoomLevel = newZoom
            }
        )
        .onAppear {
            applyZoomIfNeeded()
        }
        .onChange(of: zoomLevel) { _ in
            applyZoomIfNeeded()
        }
    }

    private func applyZoomIfNeeded() {
        webViewCoordinator?.setZoom(zoomLevel)
    }
}

// MARK: - Keyboard Shortcuts

extension BrowserView {
    var keyboardShortcuts: some View {
        ZStack {
            Button("Inspect Element") { devToolsService.toggleInspectMode() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            Button("Console") { devToolsService.selectedTab = .console }
                .keyboardShortcut("j", modifiers: [.command, .shift])
            Button("Elements") { devToolsService.selectedTab = .elements; devToolsService.refreshDOM() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            Button("Network") { devToolsService.selectedTab = .network }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("Toggle DevTools") { devToolsService.isOpen.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .option])
            Button("Close DevTools") { devToolsOpen = false; devToolsService.isOpen = false }
                .keyboardShortcut(.escape, modifiers: [])
            Button("Detach DevTools") { devToolsService.isFloating.toggle() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button("Dock Bottom") { devToolsService.dockingPosition = .bottom }
                .keyboardShortcut("1", modifiers: [.command, .shift])
            Button("Dock Right") { devToolsService.dockingPosition = .right }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            Button("Dock Left") { devToolsService.dockingPosition = .left }
                .keyboardShortcut("3", modifiers: [.command, .shift])
            Button("Find in Page") { findVisible.toggle() }
                .keyboardShortcut("f", modifiers: .command)
            Button("Focus URL") { urlFieldFocused = true }
                .keyboardShortcut("l", modifiers: .command)
            Button("Reload") { webViewCoordinator?.reload() }
                .keyboardShortcut("r", modifiers: .command)
            Button("Hard Reload") { webViewCoordinator?.reloadFromOrigin() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Button("Zoom In") { webViewCoordinator?.setZoom((webViewCoordinator?.currentZoom ?? 1.0) * 1.1) }
                .keyboardShortcut("=", modifiers: .command)
            Button("Zoom Out") { webViewCoordinator?.setZoom((webViewCoordinator?.currentZoom ?? 1.0) / 1.1) }
                .keyboardShortcut("-", modifiers: .command)
            Button("Reset Zoom") { webViewCoordinator?.setZoom(1.0) }
                .keyboardShortcut("0", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }
}

struct WebViewRepresentable: NSViewRepresentable {
    let tabId: String
    @Binding var urlString: String
    @Binding var pageTitle: String
    @Binding var isLoading: Bool
    @Binding var estimatedProgress: Double
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var coordinator: WebViewCoordinator?
    @ObservedObject var devToolsService: BrowserDevToolsService
    let persistenceService: BrowserPersistenceService
    let historyService: BrowserHistoryService
    let credentialService: BrowserCredentialService
    let downloadService: BrowserDownloadService
    let settings: SettingsService
    let onZoomChange: (Double) -> Void

    func makeCoordinator() -> WebViewCoordinator {
        let coord = WebViewCoordinator(parent: self)
        coord.persistenceService = persistenceService
        coord.historyService = historyService
        coord.credentialService = credentialService
        coord.downloadService = downloadService
        coord.settings = settings
        return coord
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        if settings.browserBlockThirdPartyCookies {
            config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        } else if settings.browserPersistData {
            config.websiteDataStore = persistenceService.dataStore(for: persistenceService.currentWorktreeId)
        } else {
            config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        }
        if !settings.browserCustomUserAgent.isEmpty {
            config.applicationNameForUserAgent = settings.browserCustomUserAgent
        } else {
            config.applicationNameForUserAgent = "Codnia/0.20.0"
        }
        if settings.browserBlockTrackers {
            injectContentRules(into: config)
        }
        devToolsService.injectScripts(into: config)
        if settings.browserAutoSaveCredentials {
            injectCredentialCapture(into: config)
            let handler = CredentialCaptureHandler(service: credentialService)
            config.userContentController.add(handler, name: "credentialCaptureHandler")
            context.coordinator.setCredentialHandler(handler)
        }
        if settings.browserDarkModeInjection {
            injectDarkModeCSS(into: config)
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")

        if settings.browserDefaultZoom != 1.0 {
            let zoom = settings.browserDefaultZoom
            let js = "document.body.style.zoom = '\(zoom)'"
            let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            config.userContentController.addUserScript(userScript)
        }

        context.coordinator.webView = webView
        context.coordinator.parent = self
        coordinator = context.coordinator
        devToolsService.webView = webView

        let worktreeId = persistenceService.currentWorktreeId
        if !worktreeId.isEmpty, settings.browserPersistData, !settings.browserBlockThirdPartyCookies {
            Task {
                await persistenceService.restoreCookies(worktreeId: worktreeId, into: webView.configuration.websiteDataStore)
                context.coordinator.restoreStorage(worktreeId: worktreeId)
            }
        }

        if let url = URL(string: urlString), url.scheme != nil {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self

        guard urlString.hasPrefix("http://") || urlString.hasPrefix("https://") else {
            return
        }

        guard !context.coordinator.navigating else {
            return
        }
        if let url = URL(string: urlString), url.scheme != nil {
            let webViewURL = webView.url?.absoluteString
            let isInitialLoad = webViewURL == nil || webViewURL == "about:blank" || webViewURL == "http://about:blank"
            let needsReload = isInitialLoad || (webViewURL != urlString && !urlString.isEmpty)
            if needsReload && !urlString.hasPrefix("about:") {
                webView.load(URLRequest(url: url))
            }
        }
    }

    private func injectContentRules(into config: WKWebViewConfiguration) {
        let rules = """
        [
            {
                "trigger": {
                    "url-filter": "doubleclick.net"
                },
                "action": { "type": "block" }
            },
            {
                "trigger": {
                    "url-filter": "googletagmanager.com"
                },
                "action": { "type": "block" }
            },
            {
                "trigger": {
                    "url-filter": "google-analytics.com"
                },
                "action": { "type": "block" }
            },
            {
                "trigger": {
                    "url-filter": "facebook.net"
                },
                "action": { "type": "block" }
            }
        ]
        """
        WKContentRuleListStore.default()?.compileContentRuleList(
            forIdentifier: "CodniaTrackers",
            encodedContentRuleList: rules
        ) { list, _ in
            if let list = list {
                config.userContentController.add(list)
            }
        }
    }

    private func injectCredentialCapture(into config: WKWebViewConfiguration) {
        let script = """
        (function() {
            if (window.__codniaCredCaptureInjected) return;
            window.__codniaCredCaptureInjected = true;

            function getOrigin() { return location.origin; }

            function tryCapture(form) {
                try {
                    if (!form || !form.elements) return;
                    var passInput = form.querySelector('input[type="password"]');
                    if (!passInput) return;
                    var usernameInput = form.querySelector('input[type="text"], input[type="email"], input[type="tel"], input:not([type])');
                    var userVal = usernameInput ? usernameInput.value : '';
                    var passVal = passInput.value || '';
                    if (!userVal || !passVal) return;
                    window.webkit.messageHandlers.credentialCaptureHandler.postMessage({
                        origin: getOrigin(),
                        username: userVal,
                        password: passVal
                    });
                } catch(e) {}
            }

            document.addEventListener('submit', function(e) {
                tryCapture(e.target);
            }, true);

            var origSubmit = HTMLFormElement.prototype.submit;
            HTMLFormElement.prototype.submit = function() {
                tryCapture(this);
                return origSubmit.apply(this, arguments);
            };
        })();
        """
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
    }

    private func injectDarkModeCSS(into config: WKWebViewConfiguration) {
        let css = """
        (function() {
            if (window.__codniaDarkInjected) return;
            window.__codniaDarkInjected = true;
            var style = document.createElement('style');
            style.id = '__codniaDarkMode';
            style.textContent = `
                html { background-color: #1a1a1a !important; color-scheme: dark; }
                body { background-color: #1a1a1a !important; color: #e0e0e0 !important; }
                body, body * {
                    background-color: var(--codnia-bg, transparent) !important;
                    color: var(--codnia-fg, inherit) !important;
                    border-color: rgba(255,255,255,0.1) !important;
                }
                img, video, picture, svg:not([fill]) { filter: brightness(0.85) contrast(1.05); }
                a { color: #6cb6ff !important; }
                input, textarea, select { background-color: #2a2a2a !important; color: #e0e0e0 !important; }
            `;
            if (document.head) {
                document.head.appendChild(style);
            } else {
                document.addEventListener('DOMContentLoaded', function() {
                    if (document.head) document.head.appendChild(style);
                });
            }
        })();
        """
        let userScript = WKUserScript(source: css, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
    }
}

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    var parent: WebViewRepresentable
    weak var webView: WKWebView?
    private var isNavigating = false
    private(set) var currentZoom: Double = 1.0
    private var zoomPerDomain: [String: Double] = [:]

    weak var persistenceService: BrowserPersistenceService?
    weak var historyService: BrowserHistoryService?
    weak var credentialService: BrowserCredentialService?
    weak var downloadService: BrowserDownloadService?
    weak var settings: SettingsService?
    private weak var devToolsService: BrowserDevToolsService?
    private let credentialHandlerBox = HandlerBox()

    func setCredentialHandler(_ handler: CredentialCaptureHandler) {
        credentialHandlerBox.handler = handler
    }

    var navigating: Bool { isNavigating }

    init(parent: WebViewRepresentable) {
        self.parent = parent
        self.devToolsService = parent.devToolsService
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        webView?.reload()
    }

    func reloadFromOrigin() {
        if let url = webView?.url {
            webView?.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30))
        }
    }

    func stopLoading() {
        webView?.stopLoading()
    }

    func load(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        webView?.load(URLRequest(url: url))
    }

    func setZoom(_ zoom: Double) {
        currentZoom = max(0.25, min(zoom, 5.0))
        let js = "document.documentElement.style.zoom = '\(currentZoom)'"
        webView?.evaluateJavaScript(js)
        if let host = webView?.url?.host, let settings = settings, settings.browserRememberZoomPerDomain {
            zoomPerDomain[host] = currentZoom
        }
        parent.onZoomChange(currentZoom)
    }

    func snapshot() {
        guard let webView = webView else { return }
        let config = WKSnapshotConfiguration()
        webView.takeSnapshot(with: config) { image, error in
            guard let image = image, error == nil else { return }
            Task { @MainActor in
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.png]
                let host = webView.url?.host ?? "page"
                panel.nameFieldStringValue = "\(host).png"
                if panel.runModal() == .OK, let url = panel.url, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: url)
                }
            }
        }
    }

    func printPage() {
        guard let webView = webView else { return }
        let printInfo = NSPrintInfo.shared
        let op = webView.printOperation(with: printInfo)
        if let window = webView.window {
            op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        }
    }

    func pdf() {
        guard let webView = webView else { return }
        let config = WKPDFConfiguration()
        let host = webView.url?.host ?? "page"
        Task {
            do {
                let data = try await webView.pdf(configuration: config)
                await MainActor.run {
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = [.pdf]
                    panel.nameFieldStringValue = "\(host).pdf"
                    if panel.runModal() == .OK, let url = panel.url {
                        try? data.write(to: url)
                    }
                }
            } catch {
                // PDF generation failed
            }
        }
    }

    func snapshotStorage(into worktreeId: String) {
        guard let webView = webView, !worktreeId.isEmpty else { return }
        let js = """
        (function() {
            try {
                var ls = {}, ss = {};
                for (var i = 0; i < localStorage.length; i++) {
                    var k = localStorage.key(i);
                    if (k) ls[k] = localStorage.getItem(k) || '';
                }
                for (var j = 0; j < sessionStorage.length; j++) {
                    var k = sessionStorage.key(j);
                    if (k) ss[k] = sessionStorage.getItem(k) || '';
                }
                return JSON.stringify({ localStorage: ls, sessionStorage: ss });
            } catch(e) { return null; }
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self,
                  let json = result as? String,
                  let data = json.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ls = dict["localStorage"] as? [String: String],
                  let ss = dict["sessionStorage"] as? [String: String] else { return }
            Task { @MainActor in
                let snapshot = BrowserStorageSnapshot(localStorage: ls, sessionStorage: ss)
                self.persistenceService?.backupStorage(worktreeId: worktreeId, snapshot: snapshot)
            }
        }
    }

    func restoreStorage(worktreeId: String) {
        guard let webView = webView, let snapshot = persistenceService?.loadStorageSnapshot(worktreeId: worktreeId) else { return }
        let applyJS = """
        (function() {
            try {
                var ls = \(dictToJS(snapshot.localStorage));
                var ss = \(dictToJS(snapshot.sessionStorage));
                for (var k in ls) { if (ls.hasOwnProperty(k)) localStorage.setItem(k, ls[k]); }
                for (var k2 in ss) { if (ss.hasOwnProperty(k2)) sessionStorage.setItem(k2, ss[k2]); }
                return true;
            } catch(e) { return false; }
        })();
        """
        webView.evaluateJavaScript(applyJS)
    }

    private func dictToJS(_ dict: [String: String]) -> String {
        let data = try? JSONSerialization.data(withJSONObject: dict)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        parent.isLoading = true
        isNavigating = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        parent.isLoading = false
        parent.estimatedProgress = 1.0
        parent.canGoBack = webView.canGoBack
        parent.canGoForward = webView.canGoForward
        isNavigating = false
        if let title = webView.title {
            parent.pageTitle = title
        }
        if let url = webView.url?.absoluteString {
            parent.urlString = url
            if let historyService = historyService, !url.isEmpty, url != "about:blank" {
                historyService.recordVisit(url: url, title: webView.title ?? "")
            }
        }
        if let host = webView.url?.host, let zoom = zoomPerDomain[host], let settings = settings, settings.browserRememberZoomPerDomain {
            currentZoom = zoom
            let js = "document.documentElement.style.zoom = '\(zoom)'"
            webView.evaluateJavaScript(js)
        }
        if let worktreeId = persistenceService?.currentWorktreeId, !worktreeId.isEmpty {
            snapshotStorage(into: worktreeId)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        parent.isLoading = false
        isNavigating = false
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        parent.isLoading = true
        isNavigating = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        parent.isLoading = false
        parent.estimatedProgress = 0
        isNavigating = false
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping @Sendable (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
        guard let response = navigationResponse.response as? HTTPURLResponse else { return }
        let devTools = parent.devToolsService
        if let url = response.url?.absoluteString {
            devTools.addResource(
                url: url,
                mimeType: response.mimeType ?? "",
                statusCode: response.statusCode
            )
        }
    }

    @MainActor
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated && navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        if let url = webView.url?.absoluteString {
            parent.urlString = url
        }
    }

    @MainActor
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }

    @MainActor
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }

    @MainActor
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = prompt
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        textField.stringValue = defaultText ?? ""
        alert.accessoryView = textField
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            completionHandler(textField.stringValue)
        } else {
            completionHandler(nil)
        }
    }
}

final class CredentialCaptureHandler: NSObject, WKScriptMessageHandler {
    weak var service: BrowserCredentialService?

    init(service: BrowserCredentialService) {
        self.service = service
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "credentialCaptureHandler",
              let dict = message.body as? [String: Any],
              let origin = dict["origin"] as? String,
              let username = dict["username"] as? String,
              let password = dict["password"] as? String else { return }
        Task { @MainActor in
            service?.promptSave(origin: origin, username: username, password: password)
        }
    }
}

final class HandlerBox: @unchecked Sendable {
    var handler: CredentialCaptureHandler?
}

private class FloatingWindowDelegate: NSObject, NSWindowDelegate {
    weak var devToolsService: BrowserDevToolsService?
    init(devToolsService: BrowserDevToolsService) { self.devToolsService = devToolsService }
    func windowWillClose(_ notification: Notification) {
        devToolsService?.isFloating = false
    }
}
