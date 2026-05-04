import Foundation

public struct Project: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var path: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        path: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.createdAt = createdAt
    }

    public static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
}
