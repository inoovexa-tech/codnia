import Foundation

public final class WorkspaceRootService {
    public static let shared = WorkspaceRootService()
    private let defaults = UserDefaults.standard
    private let key = "codnia.workspaceRoots"

    private init() {}

    public struct WorkspaceRoot: Codable, Identifiable, Equatable {
        public let id: String
        public var path: String
        public var name: String

        public static func == (lhs: WorkspaceRoot, rhs: WorkspaceRoot) -> Bool {
            lhs.id == rhs.id
        }
    }

    public func getRoots() -> [WorkspaceRoot] {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([WorkspaceRoot].self, from: data) {
            return decoded
        }
        return []
    }

    public func addRoot(path: String) -> WorkspaceRoot {
        var roots = getRoots()
        let root = WorkspaceRoot(id: UUID().uuidString, path: path, name: URL(fileURLWithPath: path).lastPathComponent)
        roots.append(root)
        save(roots)
        return root
    }

    public func removeRoot(id: String) {
        var roots = getRoots()
        roots.removeAll { $0.id == id }
        save(roots)
    }

    private func save(_ roots: [WorkspaceRoot]) {
        if let data = try? JSONEncoder().encode(roots) {
            defaults.set(data, forKey: key)
        }
    }
}
