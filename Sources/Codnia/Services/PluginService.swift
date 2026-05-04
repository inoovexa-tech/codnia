import Foundation
import Combine

@MainActor
public final class PluginService: ObservableObject {
    @Published public var plugins: [Plugin] = []
    @Published public var activePluginIds: Set<String> = []

    public init() {
        discoverPlugins()
    }

    public func discoverPlugins() {
        // Stub: scan ~/Library/Application Support/Codnia/Plugins
        plugins = []
    }

    public func activate(pluginId: String) {
        activePluginIds.insert(pluginId)
    }

    public func deactivate(pluginId: String) {
        activePluginIds.remove(pluginId)
    }

    public func executeCommand(pluginId: String, command: String, args: [String: Any]) -> PluginResponse {
        return PluginResponse(success: false, data: nil, error: "Not implemented")
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
        lhs.id == rhs.id
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
