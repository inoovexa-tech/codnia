import Foundation

public struct TaskItem: Identifiable, Codable, Equatable {
    public let id: String
    public var title: String
    public var description: String
    public var tags: [String]
    public var priority: TaskPriority
    public var isCompleted: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        tags: [String] = [],
        priority: TaskPriority = .medium,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.tags = tags
        self.priority = priority
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func == (lhs: TaskItem, rhs: TaskItem) -> Bool {
        lhs.id == rhs.id
    }
}

public enum TaskPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case urgent
}
