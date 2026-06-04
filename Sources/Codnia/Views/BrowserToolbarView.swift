import SwiftUI
import WebKit

struct BrowserToolbarView: View {
    @ObservedObject var devToolsService: BrowserDevToolsService
    @Binding var localURLText: String
    @Binding var urlString: String
    @Binding var pageTitle: String
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var estimatedProgress: Double
    @ObservedObject var downloadService: BrowserDownloadService

    let webViewCoordinator: WebViewCoordinator?
    let onClose: () -> Void
    let onPinToLeft: (() -> Void)?
    let onPinToRight: (() -> Void)?
    let onPinToTab: (() -> Void)?

    @FocusState.Binding var urlFieldFocused: Bool
    private var activeDownloadsCount: Int {
        downloadService.downloads.filter { $0.state == .downloading || $0.state == .pending }.count
    }

    var body: some View {
        HStack(spacing: 3) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
            .help("Close browser")

            Divider().frame(height: 14)

            Button(action: { webViewCoordinator?.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(canGoBack ? .textPrimary : .textTertiary)
            .disabled(!canGoBack)
            .help("Go back")

            Button(action: { webViewCoordinator?.goForward() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(canGoForward ? .textPrimary : .textTertiary)
            .disabled(!canGoForward)
            .help("Go forward")

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
            .help(isLoading ? "Stop loading" : "Reload page")

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
                    .onSubmit { submitURL() }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.bgTertiary)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.borderLight, lineWidth: 0.5)
            )
            .onAppear {
                localURLText = urlString
            }
            .onChange(of: urlString) { newValue in
                if !urlFieldFocused {
                    localURLText = newValue
                }
            }

            Button(action: onDownloadTap ?? { }) {}
                .opacity(0)
                .overlay(
                    DownloadIndicator(count: activeDownloadsCount)
                        .allowsHitTesting(false)
                )

            Button(action: { devToolsService.isOpen.toggle() }) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 10))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(devToolsService.isOpen ? .accentBlue : .textTertiary)
            .help("Toggle Developer Tools (⌘⌥I)")

            if let onPinToTab {
                Divider().frame(height: 14)
                Button(action: onPinToTab) {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 10))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.textTertiary)
                .help("Move to tab")
            }

            if onPinToLeft != nil || onPinToRight != nil {
                Divider().frame(height: 14)
            }
            if let onPinToLeft {
                Button(action: onPinToLeft) {
                    Image(systemName: "rectangle.lefthalf.inset.filled.arrow.left")
                        .font(.system(size: 10))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.textTertiary)
                .help("Pin to left panel")
            }
            if let onPinToRight {
                Button(action: onPinToRight) {
                    Image(systemName: "rectangle.righthalf.inset.filled.arrow.right")
                        .font(.system(size: 10))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.textTertiary)
                .help("Pin to right panel")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }

    private var onDownloadTap: (() -> Void)? {
        guard activeDownloadsCount > 0 else { return nil }
        return { /* could navigate to downloads sidebar */ }
    }

    private func submitURL() {
        let trimmed = localURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var finalURL = trimmed
        if !finalURL.hasPrefix("http://") && !finalURL.hasPrefix("https://") && !finalURL.hasPrefix("about:") {
            finalURL = "http://" + finalURL
        }
        urlFieldFocused = false
        webViewCoordinator?.load(urlString: finalURL)
        urlString = finalURL
    }

}

struct DownloadIndicator: View {
    let count: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 10))
                .frame(width: 22, height: 22)
                .foregroundColor(.textTertiary)
            if count > 0 {
                Text("\(min(count, 99))")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.accentRed)
                    .clipShape(Capsule())
                    .offset(x: 4, y: -2)
            }
        }
    }
}
