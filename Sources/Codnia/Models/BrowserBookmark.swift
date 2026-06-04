import Foundation

public struct BrowserBookmark: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var url: String
    public var folder: String
    public var createdAt: Date
    public var favicon: String?

    public init(
        id: UUID = UUID(),
        title: String,
        url: String,
        folder: String = "Bookmarks",
        createdAt: Date = Date(),
        favicon: String? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.folder = folder
        self.createdAt = createdAt
        self.favicon = favicon
    }

    public var host: String {
        URL(string: url)?.host ?? url
    }
}
