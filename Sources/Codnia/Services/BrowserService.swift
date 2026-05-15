import Foundation
import AppKit

@MainActor
public final class BrowserService {
    public static weak var shared: BrowserService?

    public weak var editorVM: EditorViewModel?
    public weak var settings: SettingsService?

    public init() {
        BrowserService.shared = self
    }

    public static func handleTerminalURLClick(_ url: URL) {
        let urlString = url.absoluteString
        if let service = shared, service.interceptURL(urlString) {
            return
        }
        NSWorkspace.shared.open(url)
    }

    public func interceptURL(_ urlString: String) -> Bool {
        guard let settings = settings, settings.browserEnabled else { return false }

        let normalized = normalizeURLForCheck(urlString)
        guard let host = URL(string: normalized)?.host else { return false }

        let isLocalhost = host == "localhost" || host == "127.0.0.1" || host == "0.0.0.0"
        let isPrivateIP = isPrivateIP(host)

        if settings.browserInterceptLocalhost && isLocalhost {
            promptUser(url: normalized)
            return true
        }

        if settings.browserInterceptPrivateIPs && isPrivateIP {
            promptUser(url: normalized)
            return true
        }

        return false
    }

    private func promptUser(url: String) {
        guard let settings = settings else { return }

        if settings.browserAutoRedirect {
            editorVM?.openURL(url)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Open in Browser Emulator?"
        alert.informativeText = "A local/private URL was detected:\n\n\(url)\n\nOpen it in the built-in browser or your system browser?"
        alert.addButton(withTitle: "Open in Codnia")
        alert.addButton(withTitle: "Open Externally")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            editorVM?.openURL(url)
        case .alertSecondButtonReturn:
            if let urlObj = URL(string: url) {
                NSWorkspace.shared.open(urlObj)
            }
        default:
            break
        }
    }

    private func normalizeURLForCheck(_ urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        return "http://" + trimmed
    }

    private func isPrivateIP(_ host: String) -> Bool {
        if let addr = IPv4Address(host) {
            let parts = addr.octets
            if parts[0] == 10 { return true }
            if parts[0] == 192 && parts[1] == 168 { return true }
            if parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31 { return true }
            if parts[0] == 127 { return true }
        }
        return false
    }
}

private struct IPv4Address {
    let octets: [UInt8]

    init?(_ string: String) {
        let parts = string.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4 else { return nil }
        octets = parts
    }
}
