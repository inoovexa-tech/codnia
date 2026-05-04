import Foundation

public final class RecentProjectsService {
    public static let shared = RecentProjectsService()
    private let defaults = UserDefaults.standard
    private let key = "codnia.recentProjects"
    private let maxItems = 10

    private init() {}

    public func getRecent() -> [String] {
        return defaults.stringArray(forKey: key) ?? []
    }

    public func add(_ path: String) {
        var recent = getRecent()
        recent.removeAll { $0 == path }
        recent.insert(path, at: 0)
        if recent.count > maxItems {
            recent = Array(recent.prefix(maxItems))
        }
        defaults.set(recent, forKey: key)
    }

    public func remove(_ path: String) {
        var recent = getRecent()
        recent.removeAll { $0 == path }
        defaults.set(recent, forKey: key)
    }
}
