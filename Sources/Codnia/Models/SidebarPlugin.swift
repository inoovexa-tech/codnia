import SwiftUI

@MainActor
public protocol SidebarPlugin: AnyObject {
    var id: String { get }
    var name: String { get }
    var iconName: String { get }
    var description: String { get }
    var author: String { get }
    var version: String { get }
    var commands: [PluginCommand] { get }

    @MainActor
    func makeView() -> AnyView
}

public struct PluginCommand: Identifiable {
    public let id: String
    public let title: String
    public let handler: () -> Void

    public init(id: String, title: String, handler: @escaping () -> Void) {
        self.id = id
        self.title = title
        self.handler = handler
    }
}

public struct PluginDescriptor: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let iconName: String
    public let description: String
    public let author: String
    public let version: String

    public static func == (lhs: PluginDescriptor, rhs: PluginDescriptor) -> Bool {
        lhs.id == rhs.id
    }
}

extension PluginDescriptor {
    @MainActor
    public init(from plugin: any SidebarPlugin) {
        self.id = plugin.id
        self.name = plugin.name
        self.iconName = plugin.iconName
        self.description = plugin.description
        self.author = plugin.author
        self.version = plugin.version
    }
}
