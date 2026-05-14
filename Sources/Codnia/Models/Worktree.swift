import Foundation

public struct Worktree: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var path: String
    public var branch: String
    public var isMain: Bool
    public var fileTabs: [Tab]
    public var terminalTabs: [Tab]
    public var activeTabId: String?

    public var displayName: String {
        let cleaned = branch
            .replacingOccurrences(of: "refs/heads/", with: "")
            .replacingOccurrences(of: "refs/remotes/", with: "")
        return cleaned
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        path: String,
        branch: String,
        isMain: Bool = false,
        fileTabs: [Tab] = [],
        terminalTabs: [Tab] = [],
        activeTabId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.branch = branch
        self.isMain = isMain
        self.fileTabs = fileTabs
        self.terminalTabs = terminalTabs
        self.activeTabId = activeTabId
    }

    public static func == (lhs: Worktree, rhs: Worktree) -> Bool {
        lhs.id == rhs.id
    }
}