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
    @Published var rightSidebarExpanded: Bool = false
    @Published var rightSidebarTab: RightSidebarTab = .explorer

    public init() {
        let ws = WorkspaceService()
        let s = SettingsService()
        let sr = SearchService()
        let ps = PluginService()
        let tm = TerminalViewModel()
        let ed = EditorViewModel(workspace: ws, settings: s, terminal: tm)
        let gv = GitViewModel(workspace: ws, editorVM: ed)
        let tv = TasksViewModel(workspace: ws)

        self.workspaceVM = ws
        self.settings = s
        self.searchVM = sr
        self.pluginService = ps
        self.terminalVM = tm
        self.editorVM = ed
        self.gitVM = gv
        self.tasksVM = tv

        let tasksPlugin = TasksPlugin()
        tasksPlugin.onNewTask = { [weak tv] in
            tv?.addTask(title: "New task")
        }
        ps.registerSidebarPlugin(tasksPlugin)
    }
}
