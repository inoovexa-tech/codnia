import SwiftUI

struct BrowserNetworkEntry: Identifiable, Equatable {
    let id: UUID
    let url: String
    let method: String
    let status: Int
    let statusText: String
    let contentType: String?
    let duration: Double
    let requestHeaders: [String: String]
    let responseHeaders: [String: String]
    let requestSize: Int
    let responseSize: Int
    let timestamp: Date
    let requestBody: String?
    let responseBody: String?
    let initiator: String?
    let remoteAddress: String?
    let timingBreakdown: BrowserNetworkTiming?

    var isXHR: Bool {
        method == "XHR" || contentType?.contains("xhr") == true
    }

    var host: String {
        URL(string: url)?.host ?? url
    }

    var path: String {
        URL(string: url)?.path ?? "/"
    }

    var statusColor: Color {
        switch status {
        case 200..<300: return .accentGreen
        case 300..<400: return .accentBlue
        case 400..<500: return .accentYellow
        case 500..<600: return .accentRed
        default: return .textSecondary
        }
    }
}
