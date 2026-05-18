import Foundation

public enum HTTPMethod: String, Codable, CaseIterable, Identifiable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"

    public var id: String { rawValue }
}

public enum RequestBodyType: String, Codable, CaseIterable, Identifiable {
    case none
    case json
    case formData
    case raw

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .json: return "JSON"
        case .formData: return "Form Data"
        case .raw: return "Raw"
        }
    }
}

public struct KeyValuePair: Codable, Identifiable, Equatable {
    public let id: String
    public var key: String
    public var value: String
    public var enabled: Bool

    public init(id: String = UUID().uuidString, key: String = "", value: String = "", enabled: Bool = true) {
        self.id = id
        self.key = key
        self.value = value
        self.enabled = enabled
    }
}

public struct RequestBody: Codable, Equatable {
    public var type: RequestBodyType
    public var jsonContent: String
    public var formData: [KeyValuePair]
    public var rawContent: String

    public init(
        type: RequestBodyType = .none,
        jsonContent: String = "",
        formData: [KeyValuePair] = [],
        rawContent: String = ""
    ) {
        self.type = type
        self.jsonContent = jsonContent
        self.formData = formData
        self.rawContent = rawContent
    }
}

public struct HTTPRequest: Codable, Equatable {
    public var method: HTTPMethod
    public var url: String
    public var headers: [KeyValuePair]
    public var queryParams: [KeyValuePair]
    public var body: RequestBody
    public var auth: AuthConfig

    public init(
        method: HTTPMethod = .get,
        url: String = "",
        headers: [KeyValuePair] = [],
        queryParams: [KeyValuePair] = [],
        body: RequestBody = RequestBody(),
        auth: AuthConfig = AuthConfig()
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.queryParams = queryParams
        self.body = body
        self.auth = auth
    }

    public func buildURL(env: APIEnvironment?) -> URL? {
        var baseURL = url
        if let env = env {
            baseURL = env.resolve(baseURL)
        }

        var components = URLComponents(string: baseURL)
        if !queryParams.isEmpty {
            let existingItems = components?.queryItems ?? []
            let additionalItems = queryParams.filter { $0.enabled && !$0.key.isEmpty }.map { param in
                URLQueryItem(
                    name: env?.resolve(param.key) ?? param.key,
                    value: env?.resolve(param.value) ?? param.value
                )
            }
            components?.queryItems = existingItems + additionalItems
        }
        return components?.url
    }

    public func buildHeaders(env: APIEnvironment?) -> [String: String] {
        var result: [String: String] = [:]
        for param in headers where param.enabled && !param.key.isEmpty {
            let key = env?.resolve(param.key) ?? param.key
            let value = env?.resolve(param.value) ?? param.value
            result[key] = value
        }
        result = auth.headers(for: result)
        return result
    }

    public func buildBody(env: APIEnvironment?) -> Data? {
        guard body.type != .none else { return nil }

        switch body.type {
        case .none:
            return nil
        case .json:
            let content = env?.resolve(body.jsonContent) ?? body.jsonContent
            return content.data(using: .utf8)
        case .formData:
            var components = URLComponents()
            components.queryItems = body.formData.filter { $0.enabled && !$0.key.isEmpty }.map { param in
                URLQueryItem(
                    name: env?.resolve(param.key) ?? param.key,
                    value: env?.resolve(param.value) ?? param.value
                )
            }
            return components.query?.data(using: .utf8)
        case .raw:
            let content = env?.resolve(body.rawContent) ?? body.rawContent
            return content.data(using: .utf8)
        }
    }
}