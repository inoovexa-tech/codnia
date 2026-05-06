import Foundation

public struct FileEntry: Identifiable, Codable, Equatable {
    public let id = UUID()
    public var name: String
    public var path: String
    public var isDirectory: Bool
    public var isHidden: Bool
    public var children: [FileEntry]?

    public init(
        name: String,
        path: String,
        isDirectory: Bool,
        isHidden: Bool = false,
        children: [FileEntry]? = nil
    ) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.isHidden = isHidden
        self.children = children
    }

    public static func == (lhs: FileEntry, rhs: FileEntry) -> Bool {
        lhs.path == rhs.path && lhs.name == rhs.name && lhs.isDirectory == rhs.isDirectory
    }
}
