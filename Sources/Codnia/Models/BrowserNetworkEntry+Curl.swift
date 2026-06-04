import Foundation

extension BrowserNetworkEntry {
    public func cURLCommand() -> String {
        var lines: [String] = ["curl -X \(method)"]
        for (key, value) in requestHeaders.sorted(by: { $0.key < $1.key }) {
            if key.lowercased() == "host" { continue }
            let escapedValue = value.replacingOccurrences(of: "'", with: "'\\''")
            lines.append("-H '\(key): \(escapedValue)'")
        }
        if let body = requestBody, !body.isEmpty, method != "GET" {
            let escapedBody = body
                .replacingOccurrences(of: "'", with: "'\\''")
            lines.append("--data-raw '\(escapedBody)'")
        }
        lines.append("'\(url)'")
        return lines.joined(separator: " ")
    }

    public func copyAsCurlToPasteboard() {
        let cmd = cURLCommand()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
    }
}

#if canImport(AppKit)
import AppKit
#endif
