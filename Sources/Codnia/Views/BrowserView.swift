import SwiftUI
import WebKit

struct BrowserView: View {
    let tabId: String
    @Binding var urlString: String
    @Binding var pageTitle: String
    var onNavigate: (String) -> Void
    var onClose: () -> Void
    var onPinToLeft: (() -> Void)
    var onPinToRight: (() -> Void)
    var onPinToTab: (() -> Void)?

    @State private var isLoading: Bool = false
    @State private var estimatedProgress: Double = 0
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var showURLPopover: Bool = false
    @FocusState private var urlFieldFocused: Bool
    @State private var localURLText: String = ""

    @StateObject private var devToolsService = BrowserDevToolsService()
    @State private var devToolsOpen: Bool = false
    @State private var devToolsHeight: CGFloat = 200
    @State private var devToolsFloatingWindow: NSWindow?
    @State private var floatingWindowDelegateInstance: FloatingWindowDelegate?

    var body: some View {
        ZStack {
            if devToolsOpen && !devToolsService.isFloating {
                switch devToolsService.dockingPosition {
                case .bottom:
                    VStack(spacing: 0) {
                        navigationBar
                        progressBar
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
                        navigationBar
                        progressBar
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
                        navigationBar
                        progressBar
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
                    navigationBar
                    progressBar
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
        .onDisappear {
            closeFloatingDevTools()
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

    private var navigationBar: some View {
        HStack(spacing: 3) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
            .help("Close browser")

            Divider()
                .frame(height: 14)

            Button(action: { webViewCoordinator?.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(canGoBack ? .textPrimary : .textTertiary)
            .disabled(!canGoBack)

            Button(action: { webViewCoordinator?.goForward() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(canGoForward ? .textPrimary : .textTertiary)
            .disabled(!canGoForward)

            Button(action: {
                if isLoading {
                    webViewCoordinator?.stopLoading()
                } else {
                    webViewCoordinator?.reload()
                }
            }) {
                Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textSecondary)

            Button(action: { devToolsOpen.toggle() }) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 10))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(devToolsOpen ? .accentBlue : .textTertiary)
            .help("Toggle Developer Tools")

            if let onPinToTab {
                Divider()
                    .frame(height: 14)
                Button(action: onPinToTab) {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 10))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.textTertiary)
                .help("Move to tab")
            }

            Divider()
                .frame(height: 14)

            Button(action: onPinToLeft) {
                Image(systemName: "rectangle.lefthalf.inset.filled.arrow.left")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
            .help("Pin to left panel")

            Button(action: onPinToRight) {
                Image(systemName: "rectangle.righthalf.inset.filled.arrow.right")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
            .help("Pin to right panel")

            HStack(spacing: 4) {
                if urlString.contains("https://") {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.accentGreen)
                }
                TextField("Enter URL", text: $localURLText)
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.textPrimary)
                    .focused($urlFieldFocused)
                    .onSubmit {
                        let trimmed = localURLText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        var finalURL = trimmed
                        if !finalURL.hasPrefix("http://") && !finalURL.hasPrefix("https://") {
                            finalURL = "http://" + finalURL
                        }
                        urlFieldFocused = false
                        onNavigate(finalURL)
                    }
            }
            .onAppear {
                localURLText = urlString
            }
            .onChange(of: urlString) { newValue in
                if !urlFieldFocused {
                    localURLText = newValue
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.bgTertiary)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.borderLight, lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
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
            devToolsService: devToolsService
        )
    }

    @State private var webViewCoordinator: WebViewCoordinator?

    private func navigateToURL(_ urlString: String) {
        urlFieldFocused = false
        var finalURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalURL.isEmpty {
            return
        }
        if !finalURL.hasPrefix("http://") && !finalURL.hasPrefix("https://") {
            finalURL = "http://" + finalURL
        }
        onNavigate(finalURL)
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
            Button("Toggle DevTools") { devToolsOpen.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .option])
            Button("Close DevTools") { devToolsOpen = false }
                .keyboardShortcut(.escape, modifiers: [])
            Button("Detach DevTools") { devToolsService.isFloating.toggle() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button("Dock Bottom") { devToolsService.dockingPosition = .bottom }
                .keyboardShortcut("1", modifiers: [.command, .shift])
            Button("Dock Right") { devToolsService.dockingPosition = .right }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            Button("Dock Left") { devToolsService.dockingPosition = .left }
                .keyboardShortcut("3", modifiers: [.command, .shift])
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

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        devToolsService.injectScripts(into: config)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")

        context.coordinator.webView = webView
        context.coordinator.parent = self
        coordinator = context.coordinator
        devToolsService.webView = webView

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
}

class WebViewCoordinator: NSObject, WKNavigationDelegate {
    var parent: WebViewRepresentable
    weak var webView: WKWebView?
    private var isNavigating = false

    var navigating: Bool { isNavigating }

    init(parent: WebViewRepresentable) {
        self.parent = parent
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

    func stopLoading() {
        webView?.stopLoading()
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
}

private class FloatingWindowDelegate: NSObject, NSWindowDelegate {
    weak var devToolsService: BrowserDevToolsService?
    init(devToolsService: BrowserDevToolsService) { self.devToolsService = devToolsService }
    func windowWillClose(_ notification: Notification) {
        devToolsService?.isFloating = false
    }
}
