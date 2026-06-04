import Foundation

public enum DatabaseType: String, Codable, Sendable, CaseIterable {
    case postgres
    case mysql
    case sqlite
}

public struct SSHConfig: Codable, Equatable, Sendable {
    public var host: String
    public var port: Int
    public var user: String
    public var authMethod: SSHAuthMethod
    public var keyPath: String?
    public var password: String?

    public enum SSHAuthMethod: String, Codable, Sendable, CaseIterable {
        case key
        case password
    }

    public init(
        host: String = "",
        port: Int = 22,
        user: String = "",
        authMethod: SSHAuthMethod = .key,
        keyPath: String? = nil,
        password: String? = nil
    ) {
        self.host = host
        self.port = port
        self.user = user
        self.authMethod = authMethod
        self.keyPath = keyPath
        self.password = password
    }
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
    public var sshConfig: SSHConfig?
    public var group: String?
    public var environment: String?
    public var queryTimeout: Int = 30

    public init(
        id: String = UUID().uuidString,
        name: String,
        type: DatabaseType = .postgres,
        host: String = "localhost",
        port: Int = 5432,
        user: String = "postgres",
        database: String? = nil,
        useSSL: Bool = false,
        filePath: String? = nil,
        sshConfig: SSHConfig? = nil,
        group: String? = nil,
        environment: String? = nil,
        queryTimeout: Int = 30
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
        self.sshConfig = sshConfig
        self.group = group
        self.environment = environment
        self.queryTimeout = queryTimeout
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
