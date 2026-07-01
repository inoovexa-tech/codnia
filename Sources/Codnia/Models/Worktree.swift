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
    public var tabSplitRoots: [String: SplitPane] = [:]
    public var tabActivePaneIds: [String: UUID] = [:]
    public var tabScrollPositions: [String: Double] = [:]
    public var tabSelectedRanges: [String: String] = [:]
    public var tabOrder: [String] = []

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
        activeTabId: String? = nil,
        tabSplitRoots: [String: SplitPane] = [:],
        tabActivePaneIds: [String: UUID] = [:],
        tabScrollPositions: [String: Double] = [:],
        tabSelectedRanges: [String: String] = [:],
        tabOrder: [String] = []
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.branch = branch
        self.isMain = isMain
        self.fileTabs = fileTabs
        self.terminalTabs = terminalTabs
        self.activeTabId = activeTabId
        self.tabSplitRoots = tabSplitRoots
        self.tabActivePaneIds = tabActivePaneIds
        self.tabScrollPositions = tabScrollPositions
        self.tabSelectedRanges = tabSelectedRanges
        self.tabOrder = tabOrder
    }

    enum CodingKeys: String, CodingKey {
        case id, name, path, branch, isMain, fileTabs, terminalTabs, activeTabId
        case tabSplitRoots, tabActivePaneIds, tabScrollPositions, tabSelectedRanges
        case tabOrder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        branch = try container.decode(String.self, forKey: .branch)
        isMain = try container.decode(Bool.self, forKey: .isMain)
        fileTabs = try container.decode([Tab].self, forKey: .fileTabs)
        terminalTabs = try container.decode([Tab].self, forKey: .terminalTabs)
        activeTabId = try container.decodeIfPresent(String.self, forKey: .activeTabId)
        tabSplitRoots = try container.decodeIfPresent([String: SplitPane].self, forKey: .tabSplitRoots) ?? [:]
        tabActivePaneIds = try container.decodeIfPresent([String: UUID].self, forKey: .tabActivePaneIds) ?? [:]
        tabScrollPositions = try container.decodeIfPresent([String: Double].self, forKey: .tabScrollPositions) ?? [:]
        tabSelectedRanges = try container.decodeIfPresent([String: String].self, forKey: .tabSelectedRanges) ?? [:]
        tabOrder = try container.decodeIfPresent([String].self, forKey: .tabOrder) ?? []
    }

    public static func == (lhs: Worktree, rhs: Worktree) -> Bool {
        lhs.id == rhs.id
    }
}
