import SwiftUI

public final class DatabasePlugin: SidebarPlugin {
    public let id = "database"
    public let name = "Database"
    public let iconName = "server.rack"
    public let description = "Database explorer and query tool"
    public let author = "Codnia"
    public let version = "1.0.0"

    private let databaseService: DatabaseConnectionService
    private let editorVM: EditorViewModel

    public var commands: [PluginCommand] {
        [
            PluginCommand(id: "\(id).newQuery", title: "Database: New Query") { [weak self] in
                self?.onNewQuery?()
            }
        ]
    }

    var onNewQuery: (() -> Void)?

    public init(databaseService: DatabaseConnectionService, editorVM: EditorViewModel) {
        self.databaseService = databaseService
        self.editorVM = editorVM
    }

    public func makeView() -> AnyView {
        AnyView(
            DatabaseExplorerView()
                .environmentObject(databaseService)
                .environmentObject(editorVM)
        )
    }
}
