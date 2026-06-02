import Foundation

public struct FileEntry: Identifiable, Codable, Equatable {
    public var id: String { path }
    public var name: String
    public var path: String
    public var isDirectory: Bool
    public var isHidden: Bool
    public var dateModified: Date?
    public var fileSize: Int64?
    public var kind: String?
    public var children: [FileEntry]?

    public init(
        name: String,
        path: String,
        isDirectory: Bool,
        isHidden: Bool = false,
        dateModified: Date? = nil,
        fileSize: Int64? = nil,
        kind: String? = nil,
        children: [FileEntry]? = nil
    ) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.isHidden = isHidden
        self.dateModified = dateModified
        self.fileSize = fileSize
        self.kind = kind
        self.children = children
    }

    public static func == (lhs: FileEntry, rhs: FileEntry) -> Bool {
        lhs.path == rhs.path && lhs.name == rhs.name && lhs.isDirectory == rhs.isDirectory
    }
}
