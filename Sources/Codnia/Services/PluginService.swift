import Foundation
import Combine

@MainActor
public final class PluginService: ObservableObject {
    @Published public var plugins: [Plugin] = []
    @Published public var activePluginIds: Set<String> = []

    private var sidebarPluginRegistry: [String: any SidebarPlugin] = [:]
    private let defaults = UserDefaults.standard
    private let activeIdsKey = "codnia.plugins.activeIds.v2"
    private let legacyKey = "codnia.plugins.activeIds"

    public init() {
        migrateAndLoadActiveIds()
    }

    // MARK: - Sidebar Plugin Registry

    public func registerSidebarPlugin(_ plugin: any SidebarPlugin) {
        sidebarPluginRegistry[plugin.id] = plugin
        let wasActivated = activePluginIds.contains(plugin.id)
        if !plugins.contains(where: { $0.id == plugin.id }) {
            plugins.append(Plugin(
                id: plugin.id,
                name: plugin.name,
                version: plugin.version,
                description: plugin.description,
                author: plugin.author,
                isActive: wasActivated
            ))
        }
    }

    public func unregisterSidebarPlugin(id: String) {
        sidebarPluginRegistry.removeValue(forKey: id)
        plugins.removeAll { $0.id == id }
        activePluginIds.remove(id)
        saveActiveIds()
    }

    public func plugin(withId id: String) -> (any SidebarPlugin)? {
        sidebarPluginRegistry[id]
    }

    public var activeSidebarPlugins: [any SidebarPlugin] {
        activePluginIds.compactMap { sidebarPluginRegistry[$0] }
    }

    public var allSidebarPlugins: [any SidebarPlugin] {
        Array(sidebarPluginRegistry.values)
    }

    public var allCommands: [PluginCommand] {
        activeSidebarPlugins.flatMap { $0.commands }
    }

    // MARK: - Activation

    public func activate(pluginId: String) {
        activePluginIds.insert(pluginId)
        plugins = plugins.map { plugin in
            if plugin.id == pluginId {
                var updated = plugin
                updated.isActive = true
                return updated
            }
            return plugin
        }
        saveActiveIds()
    }

    public func deactivate(pluginId: String) {
        activePluginIds.remove(pluginId)
        plugins = plugins.map { plugin in
            if plugin.id == pluginId {
                var updated = plugin
                updated.isActive = false
                return updated
            }
            return plugin
        }
        saveActiveIds()
    }

    public func isActive(pluginId: String) -> Bool {
        activePluginIds.contains(pluginId)
    }

    public func togglePlugin(pluginId: String) {
        if isActive(pluginId: pluginId) {
            deactivate(pluginId: pluginId)
        } else {
            activate(pluginId: pluginId)
        }
    }

    public func executeCommand(pluginId: String, command: String, args: [String: Any]) -> PluginResponse {
        return PluginResponse(success: false, data: nil, error: "Not implemented")
    }

    // MARK: - Persistence

    private func migrateAndLoadActiveIds() {
        if defaults.object(forKey: legacyKey) != nil {
            defaults.removeObject(forKey: legacyKey)
        }

        if let data = defaults.array(forKey: activeIdsKey) as? [String] {
            activePluginIds = Set(data)
        } else {
            activePluginIds = Set(["tasks", "database", "notes"])
            saveActiveIds()
        }
    }

    private func saveActiveIds() {
        defaults.set(Array(activePluginIds), forKey: activeIdsKey)
    }

    public func discoverPlugins() {
        // Stub: scan ~/Library/Application Support/Codnia/Plugins
    }
}

public struct Plugin: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var version: String
    public var description: String
    public var author: String
    public var isActive: Bool

    public static func == (lhs: Plugin, rhs: Plugin) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.isActive == rhs.isActive
    }
}

public struct PluginResponse: Codable {
    public let success: Bool
    public let data: String?
    public let error: String?
}

public struct MarketplacePlugin: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var version: String
    public var author: String
    public var description: String
    public var category: String
    public var downloadUrl: String?

    public static func == (lhs: MarketplacePlugin, rhs: MarketplacePlugin) -> Bool {
        lhs.id == rhs.id
    }
}

public struct MarketplaceCategory: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String

    public static func == (lhs: MarketplaceCategory, rhs: MarketplaceCategory) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
public final class MarketplaceService {
    public static let shared = MarketplaceService()

    public func getFeaturedPlugins() -> [MarketplacePlugin] {
        return []
    }

    public func getCategories() -> [MarketplaceCategory] {
        return [
            MarketplaceCategory(id: "themes", name: "Themes"),
            MarketplaceCategory(id: "languages", name: "Languages"),
            MarketplaceCategory(id: "tools", name: "Tools"),
            MarketplaceCategory(id: "integrations", name: "Integrations"),
        ]
    }

    public func searchPlugins(query: String) -> [MarketplacePlugin] {
        return []
    }

    public func getPluginsByCategory(category: String) -> [MarketplacePlugin] {
        return []
    }

    public func installPlugin(pluginId: String) -> Result<String, Error> {
        return .failure(NSError(domain: "PluginService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"]))
    }

    public func uninstallPlugin(pluginId: String) -> Result<String, Error> {
        return .failure(NSError(domain: "PluginService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"]))
    }

    public func publishPlugin(name: String, version: String, author: String, description: String) -> Result<String, Error> {
        return .failure(NSError(domain: "PluginService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"]))
    }
}
