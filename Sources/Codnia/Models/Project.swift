import Foundation

public struct Project: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var path: String
    public var createdAt: Date
    public var worktrees: [Worktree]
    public var activeWorktreeId: String?
    public var customIconPath: String?
    public var isWorktreesExpanded: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        path: String,
        createdAt: Date = Date(),
        worktrees: [Worktree] = [],
        activeWorktreeId: String? = nil,
        customIconPath: String? = nil,
        isWorktreesExpanded: Bool = false
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.createdAt = createdAt
        self.worktrees = worktrees
        self.activeWorktreeId = activeWorktreeId
        self.customIconPath = customIconPath
        self.isWorktreesExpanded = isWorktreesExpanded
    }

    public static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }

    var activeWorktree: Worktree? {
        worktrees.first { $0.id == activeWorktreeId } ?? worktrees.first
    }

    var detectedIconPath: String? {
        if let custom = customIconPath, FileManager.default.fileExists(atPath: custom) {
            return custom
        }
        let commonIcons = [
            "favicon.ico",
            "icon.png",
            "logo.png",
            "icon.svg",
            "Icon.png",
            "apple-touch-icon.png",
            "apple-touch-icon-precomposed.png",
            "favicon.svg",
            "logo.svg",
            "logo.jpg",
            "logo.jpeg",
            "icon.webp",
            "favicon-16x16.png",
            "favicon-32x32.png",
            "android-chrome-192x192.png",
            "android-chrome-512x512.png",
            "mstile-150x150.png"
        ]
        for iconName in commonIcons {
            let iconPath = (path as NSString).appendingPathComponent(iconName)
            if FileManager.default.fileExists(atPath: iconPath) {
                return iconPath
            }
        }
        return nil
    }

    var hasCustomIcon: Bool {
        customIconPath != nil || detectedIconPath != nil
    }

    enum CodingKeys: String, CodingKey {
        case id, name, path, createdAt
        case worktrees
        case activeWorktreeId
        case customIconPath
        case worktreesExpanded
        case fileTabs
        case terminalTabs
        case activeTabId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        customIconPath = try container.decodeIfPresent(String.self, forKey: .customIconPath)
        isWorktreesExpanded = try container.decodeIfPresent(Bool.self, forKey: .worktreesExpanded) ?? false

        if let worktrees = try container.decodeIfPresent([Worktree].self, forKey: .worktrees) {
            self.worktrees = worktrees
            self.activeWorktreeId = try container.decodeIfPresent(String.self, forKey: .activeWorktreeId)
        } else {
            let legacyFileTabs: [Tab] = (try? container.decodeIfPresent([Tab].self, forKey: .fileTabs)) ?? []
            let legacyTerminalTabs: [Tab] = (try? container.decodeIfPresent([Tab].self, forKey: .terminalTabs)) ?? []
            let legacyActiveTabId: String? = try? container.decodeIfPresent(String.self, forKey: .activeTabId)

            let mainWorktree = Worktree(
                name: "main",
                path: path,
                branch: "main",
                isMain: true,
                fileTabs: legacyFileTabs,
                terminalTabs: legacyTerminalTabs,
                activeTabId: legacyActiveTabId
            )
            self.worktrees = [mainWorktree]
            self.activeWorktreeId = mainWorktree.id
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(worktrees, forKey: .worktrees)
        try container.encodeIfPresent(activeWorktreeId, forKey: .activeWorktreeId)
        try container.encodeIfPresent(customIconPath, forKey: .customIconPath)
        try container.encode(isWorktreesExpanded, forKey: .worktreesExpanded)
    }
}