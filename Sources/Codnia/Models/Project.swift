import Foundation

public struct Project: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var path: String
    public var createdAt: Date
    public var fileTabs: [Tab]
    public var terminalTabs: [Tab]
    public var activeTabId: String?
    public var customIconPath: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        path: String,
        createdAt: Date = Date(),
        fileTabs: [Tab] = [],
        terminalTabs: [Tab] = [],
        activeTabId: String? = nil,
        customIconPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.createdAt = createdAt
        self.fileTabs = fileTabs
        self.terminalTabs = terminalTabs
        self.activeTabId = activeTabId
        self.customIconPath = customIconPath
    }

    public static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
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
}
