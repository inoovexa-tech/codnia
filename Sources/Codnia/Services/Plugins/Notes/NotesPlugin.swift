import SwiftUI

public final class NotesPlugin: SidebarPlugin {
    public let id = "notes"
    public let name = "Notes"
    public let iconName = "note.text"
    public let description = "Markdown notes manager with CRUD operations, templates, and organization"
    public let author = "Codnia"
    public let version = "1.0.0"

    public var commands: [PluginCommand] {
        [
            PluginCommand(id: "\(id).newNote", title: "Notes: New Note") { [weak self] in
                self?.onNewNote?()
            },
            PluginCommand(id: "\(id).refresh", title: "Notes: Refresh") { [weak self] in
                self?.onRefresh?()
            }
        ]
    }

    var onNewNote: (() -> Void)?
    var onRefresh: (() -> Void)?

    public init() {}

    public func makeView() -> AnyView {
        AnyView(NotesView())
    }
}