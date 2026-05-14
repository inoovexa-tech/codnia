import Foundation

public enum TabType: String, Codable, Equatable {
    case file
    case terminal
    case opencode
    case claude
    case codex
    case diff
    case image
    case pdf
    case queryResult

    public var isAI: Bool {
        switch self {
        case .opencode, .claude, .codex: return true
        default: return false
        }
    }
}

public enum PreviewType: String, Codable, Equatable {
    case markdown
    case html
    case unknown
}

public struct Tab: Identifiable, Codable, Equatable {
    public let id: String
    public var path: String
    public var name: String
    public var isModified: Bool
    public var language: String
    public var type: TabType
    public var terminalId: String?
    public var queryConnectionId: String?
    public var querySql: String?

    public init(
        id: String = UUID().uuidString,
        path: String = "",
        name: String = "Untitled",
        isModified: Bool = false,
        language: String = "Plain Text",
        type: TabType = .file,
        terminalId: String? = nil,
        queryConnectionId: String? = nil,
        querySql: String? = nil
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.isModified = isModified
        self.language = language
        self.type = type
        self.terminalId = terminalId
        self.queryConnectionId = queryConnectionId
        self.querySql = querySql
    }

    public static func == (lhs: Tab, rhs: Tab) -> Bool {
        lhs.id == rhs.id
            && lhs.path == rhs.path
            && lhs.name == rhs.name
            && lhs.isModified == rhs.isModified
            && lhs.language == rhs.language
            && lhs.type == rhs.type
            && lhs.terminalId == rhs.terminalId
            && lhs.queryConnectionId == rhs.queryConnectionId
            && lhs.querySql == rhs.querySql
    }
}
