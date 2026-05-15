import SwiftUI
import WebKit

struct BrowserView: View {
    let tabId: String
    @Binding var urlString: String
    @Binding var pageTitle: String
    var onNavigate: (String) -> Void
    var onClose: () -> Void

    @State private var isLoading: Bool = false
    @State private var estimatedProgress: Double = 0
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var showURLPopover: Bool = false
    @FocusState private var urlFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            progressBar
            webViewRepresentable
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 6) {
            Button(action: { webViewCoordinator?.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(canGoBack ? .textPrimary : .textTertiary)
            .disabled(!canGoBack)

            Button(action: { webViewCoordinator?.goForward() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 24)
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
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textSecondary)

            HStack(spacing: 4) {
                if urlString.contains("https://") {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.accentGreen)
                }
                TextField("Enter URL", text: $urlString)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.textPrimary)
                    .focused($urlFieldFocused)
                    .onSubmit {
                        navigateToURL(urlString)
                    }
                    .onHover { hovering in
                        if hovering { NSCursor.iBeam.push() }
                        else { NSCursor.pop() }
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.bgTertiary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.borderLight, lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
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
            coordinator: $webViewCoordinator
        )
    }

    @State private var webViewCoordinator: WebViewCoordinator?

    private func navigateToURL(_ urlString: String) {
        urlFieldFocused = false
        onNavigate(urlString)
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

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")

        context.coordinator.webView = webView
        context.coordinator.parent = self
        coordinator = context.coordinator

        if let url = URL(string: urlString), url.scheme != nil {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }
}

class WebViewCoordinator: NSObject, WKNavigationDelegate {
    var parent: WebViewRepresentable
    weak var webView: WKWebView?

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
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        parent.isLoading = false
        parent.estimatedProgress = 1.0
        parent.canGoBack = webView.canGoBack
        parent.canGoForward = webView.canGoForward
        if let title = webView.title {
            parent.pageTitle = title
        }
        if let url = webView.url?.absoluteString {
            parent.urlString = url
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        parent.isLoading = false
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        parent.isLoading = true
        parent.estimatedProgress = 0.1
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        parent.isLoading = false
        parent.estimatedProgress = 0
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        if let url = webView.url?.absoluteString {
            parent.urlString = url
        }
    }
}
