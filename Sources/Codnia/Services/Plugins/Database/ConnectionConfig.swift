import Foundation

public enum DatabaseType: String, Codable, Sendable, CaseIterable {
    case postgres
    case mysql
    case sqlite
}

public struct ConnectionConfig: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var type: DatabaseType
    public var host: String
    public var port: Int
    public var user: String
    public var database: String?
    public var useSSL: Bool
    public var filePath: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        type: DatabaseType = .postgres,
        host: String = "localhost",
        port: Int = 5432,
        user: String = "postgres",
        database: String? = nil,
        useSSL: Bool = false,
        filePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.host = host
        self.port = port
        self.user = user
        self.database = database
        self.useSSL = useSSL
        self.filePath = filePath
    }
}

public enum SessionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected(handleID: String)
    case error(String)

    public var isConnected: Bool {
        if case .connected = self { true } else { false }
    }

    public var handleID: String? {
        if case .connected(let id) = self { id } else { nil }
    }
}
