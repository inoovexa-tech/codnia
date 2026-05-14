import Foundation

public struct SearchResult: Identifiable, Equatable, Sendable {
    public let id: String
    public let filePath: String
    public let matchingLine: String
    public let projectId: String
    public let projectName: String
    public let worktreeId: String
    public let worktreeName: String
    public let matchType: SearchMatchType

    public init(
        id: String = UUID().uuidString,
        filePath: String,
        matchingLine: String,
        projectId: String,
        projectName: String,
        worktreeId: String,
        worktreeName: String,
        matchType: SearchMatchType
    ) {
        self.id = id
        self.filePath = filePath
        self.matchingLine = matchingLine
        self.projectId = projectId
        self.projectName = projectName
        self.worktreeId = worktreeId
        self.worktreeName = worktreeName
        self.matchType = matchType
    }

    public static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

public enum SearchMatchType: String, Codable, Equatable, Sendable {
    case content
    case filename
}
