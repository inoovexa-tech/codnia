import Foundation

public struct Project: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var path: String
    public var createdAt: Date
    public var fileTabs: [Tab]
    public var terminalTabs: [Tab]
    public var activeTabId: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        path: String,
        createdAt: Date = Date(),
        fileTabs: [Tab] = [],
        terminalTabs: [Tab] = [],
        activeTabId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.createdAt = createdAt
        self.fileTabs = fileTabs
        self.terminalTabs = terminalTabs
        self.activeTabId = activeTabId
    }

    public static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
}
