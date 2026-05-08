import Foundation

public enum DiffChangeType: String, Codable, Equatable {
    case unchanged
    case added
    case removed
    case changed
}

public struct DiffLine: Identifiable, Codable, Equatable {
    public let id: UUID
    public let originalLine: String?
    public let modifiedLine: String?
    public let originalLineNumber: Int?
    public let modifiedLineNumber: Int?
    public let type: DiffChangeType

    public var isChanged: Bool {
        type != .unchanged
    }

    public init(
        id: UUID = UUID(),
        originalLine: String?,
        modifiedLine: String?,
        originalLineNumber: Int?,
        modifiedLineNumber: Int?,
        type: DiffChangeType
    ) {
        self.id = id
        self.originalLine = originalLine
        self.modifiedLine = modifiedLine
        self.originalLineNumber = originalLineNumber
        self.modifiedLineNumber = modifiedLineNumber
        self.type = type
    }
}

public enum DiffViewMode: String, Equatable {
    case sideBySide = "Split"
    case inline = "Unified"
}
