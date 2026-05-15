import SwiftUI
import WebKit

struct HTMLPreviewView: View {
    let content: String
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.bgPrimary

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
            }

            HTMLWebView(content: content, isLoading: $isLoading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HTMLWebView: NSViewRepresentable {
    let content: String
    @Binding var isLoading: Bool

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences = WKPreferences()
        config.preferences.isElementFullscreenEnabled = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let current = context.coordinator.lastLoadedContent
        guard current != content else { return }
        context.coordinator.lastLoadedContent = content
        isLoading = true
        webView.loadHTMLString(content, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        var lastLoadedContent: String?

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}