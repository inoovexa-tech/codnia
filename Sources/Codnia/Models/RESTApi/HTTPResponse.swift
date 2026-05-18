import Foundation

public struct HTTPResponse: Identifiable, Equatable {
    public let id: String
    public let request: HTTPRequest
    public let statusCode: Int
    public let statusMessage: String
    public let headers: [String: String]
    public let body: Data
    public let timing: TimeInterval
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        request: HTTPRequest,
        statusCode: Int,
        statusMessage: String,
        headers: [String: String],
        body: Data,
        timing: TimeInterval,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.request = request
        self.statusCode = statusCode
        self.statusMessage = statusMessage
        self.headers = headers
        self.body = body
        self.timing = timing
        self.timestamp = timestamp
    }

    public var bodyString: String {
        String(data: body, encoding: .utf8) ?? ""
    }

    public var bodyPrettyJSON: String? {
        guard let json = try? JSONSerialization.jsonObject(with: body, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return prettyString
    }

    public var isJSON: Bool {
        bodyPrettyJSON != nil
    }

    public var statusCategory: StatusCategory {
        switch statusCode {
        case 100..<200: return .informational
        case 200..<300: return .success
        case 300..<400: return .redirect
        case 400..<500: return .clientError
        case 500..<600: return .serverError
        default: return .unknown
        }
    }

    public var formattedSize: String {
        let bytes = body.count
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }

    public var formattedTiming: String {
        if timing < 1 {
            return String(format: "%.0f ms", timing * 1000)
        } else {
            return String(format: "%.2f s", timing)
        }
    }

    public enum StatusCategory {
        case informational
        case success
        case redirect
        case clientError
        case serverError
        case unknown
    }
}