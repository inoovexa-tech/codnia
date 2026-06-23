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
    public let splitVM: SplitViewModel
    public let pluginService: PluginService
    public let tasksVM: TasksViewModel
    public let databaseService: DatabaseConnectionService
    public let notesVM: NotesViewModel
    public var restApiVM: RESTApiViewModel
    @Published var rightSidebarExpanded: Bool = false
    @Published var rightSidebarTab: RightSidebarTab = .explorer
    @Published var showGlobalSearchModal: Bool = false
    @Published var showAddProjectModal: Bool = false

    private var previousWorktreeId: String?

    public init() {
        let ws = WorkspaceService()
        let s = SettingsService()
        let sr = SearchService()
        let ps = PluginService()
        let tm = TerminalViewModel()
        let ed = EditorViewModel(workspace: ws, settings: s, terminal: tm)
        let gv = GitViewModel(workspace: ws, editorVM: ed)
        let sp = SplitViewModel()
        ed.splitVM = sp
        let tv = TasksViewModel(workspace: ws)
        let db = DatabaseConnectionService()
        let nv = NotesViewModel()
        let rest = RESTApiViewModel(projectPath: ws.activeProject?.activeWorktree?.path)
        self.workspaceVM = ws
        self.settings = s
        self.searchVM = sr
        self.pluginService = ps
        self.terminalVM = tm
        self.editorVM = ed
        self.gitVM = gv
        self.splitVM = sp
        self.tasksVM = tv
        self.databaseService = db
        self.notesVM = nv
        self.restApiVM = rest

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

        let notesPlugin = NotesPlugin()
        notesPlugin.onNewNote = { [weak nv] in
            nv?.showNewNoteSheet = true
        }
        notesPlugin.onRefresh = { [weak nv] in
            nv?.refreshNotes()
        }
        ps.registerSidebarPlugin(notesPlugin)

        let restApiPlugin = RESTApiPlugin()
        restApiPlugin.viewModel = rest
        ps.registerSidebarPlugin(restApiPlugin)

        ws.$activeProject.receive(on: DispatchQueue.main).sink { [weak self] project in
            guard let self = self else { return }
            self.restApiVM.reloadForProject(projectPath: project?.activeWorktree?.path)

            if let prevId = self.previousWorktreeId,
               let prevProject = self.workspaceVM.projects.first(where: { $0.worktrees.contains { $0.id == prevId } }),
               let prevWtIdx = prevProject.worktrees.firstIndex(where: { $0.id == prevId }),
               let projIdx = self.workspaceVM.projects.firstIndex(where: { $0.id == prevProject.id }) {
                self.workspaceVM.saveProjects()
            }

            if project?.activeWorktree != nil {
                self.previousWorktreeId = project?.activeWorktree?.id
            }
        }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
}