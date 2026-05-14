import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    public let workspaceVM: WorkspaceService
    public let settings: SettingsService
    public let searchVM: SearchService
    public let terminalVM: TerminalViewModel
    public let editorVM: EditorViewModel
    public let gitVM: GitViewModel
    public let pluginService: PluginService
    public let tasksVM: TasksViewModel
    public let databaseService: DatabaseConnectionService
    @Published var rightSidebarExpanded: Bool = false
    @Published var rightSidebarTab: RightSidebarTab = .explorer
    @Published var showGlobalSearchModal: Bool = false

    public init() {
        let ws = WorkspaceService()
        let s = SettingsService()
        let sr = SearchService()
        let ps = PluginService()
        let tm = TerminalViewModel()
        let ed = EditorViewModel(workspace: ws, settings: s, terminal: tm)
        let gv = GitViewModel(workspace: ws, editorVM: ed)
        let tv = TasksViewModel(workspace: ws)
        let db = DatabaseConnectionService()

        self.workspaceVM = ws
        self.settings = s
        self.searchVM = sr
        self.pluginService = ps
        self.terminalVM = tm
        self.editorVM = ed
        self.gitVM = gv
        self.tasksVM = tv
        self.databaseService = db

        let tasksPlugin = TasksPlugin()
        tasksPlugin.onNewTask = { [weak tv] in
            tv?.addTask(title: "New task")
        }
        ps.registerSidebarPlugin(tasksPlugin)

        let dbPlugin = DatabasePlugin(databaseService: db, editorVM: ed)
        dbPlugin.onNewQuery = { [weak ed, weak db] in
            guard let ed = ed, db?.hasConnections == true else { return }
            ed.newQueryTab(connectionId: db?.connections.first?.id)
        }
        ps.registerSidebarPlugin(dbPlugin)
    }
}
