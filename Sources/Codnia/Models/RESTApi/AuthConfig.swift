import Foundation

public enum AuthType: String, Codable, CaseIterable, Identifiable {
    case none
    case basic
    case bearerToken
    case apiKey

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .basic: return "Basic Auth"
        case .bearerToken: return "Bearer Token"
        case .apiKey: return "API Key"
        }
    }
}

public struct AuthConfig: Codable, Equatable {
    public var type: AuthType
    public var username: String
    public var password: String
    public var token: String
    public var apiKeyName: String
    public var apiKeyValue: String
    public var apiKeyLocation: APIKeyLocation
    public var enabled: Bool

    public enum APIKeyLocation: String, Codable, CaseIterable {
        case header
        case queryParam
    }

    public init(
        type: AuthType = .none,
        username: String = "",
        password: String = "",
        token: String = "",
        apiKeyName: String = "",
        apiKeyValue: String = "",
        apiKeyLocation: APIKeyLocation = .header,
        enabled: Bool = true
    ) {
        self.type = type
        self.username = username
        self.password = password
        self.token = token
        self.apiKeyName = apiKeyName
        self.apiKeyValue = apiKeyValue
        self.apiKeyLocation = apiKeyLocation
        self.enabled = enabled
    }

    public func headers(for baseHeaders: [String: String]) -> [String: String] {
        guard enabled else { return baseHeaders }
        var result = baseHeaders
        switch type {
        case .none:
            break
        case .basic:
            if !username.isEmpty {
                let credentials = "\(username):\(password)"
                if let data = credentials.data(using: .utf8) {
                    let base64 = data.base64EncodedString()
                    result["Authorization"] = "Basic \(base64)"
                }
            }
        case .bearerToken:
            if !token.isEmpty {
                result["Authorization"] = "Bearer \(token)"
            }
        case .apiKey:
            if apiKeyLocation == .header && !apiKeyName.isEmpty && !apiKeyValue.isEmpty {
                result[apiKeyName] = apiKeyValue
            }
        }
        return result
    }

    public func queryItems(for baseItems: [URLQueryItem]) -> [URLQueryItem] {
        guard enabled else { return baseItems }
        var result = baseItems
        if type == .apiKey && apiKeyLocation == .queryParam && !apiKeyName.isEmpty && !apiKeyValue.isEmpty {
            result.append(URLQueryItem(name: apiKeyName, value: apiKeyValue))
        }
        return result
    }
}