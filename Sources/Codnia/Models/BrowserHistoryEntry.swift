import Foundation

public struct BrowserHistoryEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var url: String
    public var title: String
    public var visitedAt: Date
    public var visitCount: Int

    public init(
        id: UUID = UUID(),
        url: String,
        title: String,
        visitedAt: Date = Date(),
        visitCount: Int = 1
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.visitedAt = visitedAt
        self.visitCount = visitCount
    }

    public var host: String {
        URL(string: url)?.host ?? url
    }

    public var dayKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: visitedAt)
    }
}
