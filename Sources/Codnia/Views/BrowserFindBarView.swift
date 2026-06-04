import SwiftUI
import WebKit

struct BrowserFindBarView: View {
    let coordinator: WebViewCoordinator
    @Binding var isVisible: Bool
    @State private var searchText: String = ""
    @State private var currentMatch: Int = 0
    @State private var totalMatches: Int = 0
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
                .frame(width: 14)

            TextField("Find in page", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.textPrimary)
                .focused($focused)
                .onSubmit { findNext() }
                .onChange(of: searchText) { newValue in
                    performFind(newValue, forward: true)
                }

            Text(totalMatches > 0 ? "\(currentMatch)/\(totalMatches)" : (searchText.isEmpty ? "" : "No results"))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.textTertiary)
                .frame(minWidth: 50, alignment: .trailing)

            Button(action: { findPrev() }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 9))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textSecondary)
            .disabled(searchText.isEmpty)

            Button(action: { findNext() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textSecondary)
            .disabled(searchText.isEmpty)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
        .onAppear { focused = true }
        .onExitCommand(perform: close)
    }

    private func performFind(_ text: String, forward: Bool) {
        guard let webView = coordinator.webView else { return }
        if text.isEmpty {
            webView.evaluateJavaScript("window.find ? window.find('', false, false, true) : false")
            currentMatch = 0
            totalMatches = 0
            return
        }
        let config = WKFindConfiguration()
        config.backwards = !forward
        config.caseSensitive = false
        config.wraps = true
        webView.find(text, configuration: config) { result in
            DispatchQueue.main.async {
                if result.matchFound {
                    currentMatch = max(1, currentMatch + (forward ? 1 : -1))
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let js = """
            (function() {
                try {
                    var count = 0;
                    var body = document.body.innerText || '';
                    var idx = 0;
                    var target = \(jsString(text));
                    var lowerBody = body.toLowerCase();
                    var lowerTarget = target.toLowerCase();
                    while ((idx = lowerBody.indexOf(lowerTarget, idx)) !== -1) {
                        count++;
                        idx += lowerTarget.length;
                    }
                    return count;
                } catch(e) { return 0; }
            })();
            """
            webView.evaluateJavaScript(js) { result, _ in
                if let count = result as? Int {
                    DispatchQueue.main.async {
                        totalMatches = count
                        if currentMatch < 1 { currentMatch = 1 }
                        if currentMatch > count { currentMatch = count }
                    }
                }
            }
        }
    }

    private func findNext() {
        currentMatch = min(currentMatch + 1, max(totalMatches, 1))
        performFind(searchText, forward: true)
    }

    private func findPrev() {
        currentMatch = max(currentMatch - 1, 1)
        performFind(searchText, forward: false)
    }

    private func close() {
        isVisible = false
        searchText = ""
        currentMatch = 0
        totalMatches = 0
        coordinator.webView?.evaluateJavaScript("window.find ? window.find('', false, false, true) : false")
    }

    private func jsString(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "'\(escaped)'"
    }
}
