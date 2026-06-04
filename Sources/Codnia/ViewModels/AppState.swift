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
    public let browserService: BrowserService
    @Published public var historyService: BrowserHistoryService
    @Published public var credentialService: BrowserCredentialService
    @Published public var downloadService: BrowserDownloadService
    public let persistenceService: BrowserPersistenceService
    public var restApiVM: RESTApiViewModel
    @Published var rightSidebarExpanded: Bool = false
    @Published var rightSidebarTab: RightSidebarTab = .explorer
    @Published var showGlobalSearchModal: Bool = false
    @Published var showAddProjectModal: Bool = false

    @Published var browserExpanded: Bool = false
    @Published var browserSide: BrowserSide = .right
    @Published var browserURL: String = ""
    @Published var browserTitle: String = ""
    @Published var browserWidth: CGFloat = 500
    @Published var findVisible: Bool = false
    private var previousWorktreeId: String?

    public enum BrowserSide: String {
        case left
        case right
    }

    public func closeBrowser() {
        browserExpanded = false
    }

    public func moveBrowserToSide(_ side: BrowserSide) {
        browserSide = side
        browserExpanded = true
    }

    public func openURL(_ urlString: String, in location: BrowserOpenIn) {
        switch location {
        case .tab:
            editorVM.openURL(urlString)
        case .leftPanel:
            browserURL = urlString
            browserSide = .left
            browserExpanded = true
        case .rightPanel:
            browserURL = urlString
            browserSide = .right
            browserExpanded = true
        }
    }

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
        let bs = BrowserService()
        let history = BrowserHistoryService()
        let credentials = BrowserCredentialService()
        let downloads = BrowserDownloadService()
        let persistence = BrowserPersistenceService.shared
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
        self.browserService = bs
        self.historyService = history
        self.credentialService = credentials
        self.downloadService = downloads
        self.persistenceService = persistence
        self.restApiVM = rest

        bs.editorVM = ed
        bs.settings = s
        downloads.downloadPath = s.browserDownloadPath

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

        let browserPlugin = BrowserPlugin()
        browserPlugin.onNewTab = { [weak self] in
            guard let self = self else { return }
            self.openURL("about:blank", in: .tab)
        }
        browserPlugin.onClearHistory = { [weak self] in
            self?.historyService.clearAll()
        }
        browserPlugin.onShowDownloads = { [weak self] in
            self?.rightSidebarTab = .plugin("browser")
            self?.rightSidebarExpanded = true
        }
        ps.registerSidebarPlugin(browserPlugin)

        bs.appState = self

        ws.$activeProject.receive(on: DispatchQueue.main).sink { [weak self] project in
            guard let self = self else { return }
            self.restApiVM.reloadForProject(projectPath: project?.activeWorktree?.path)

            if let prevId = self.previousWorktreeId,
               let prevProject = self.workspaceVM.projects.first(where: { $0.worktrees.contains { $0.id == prevId } }),
               let prevWtIdx = prevProject.worktrees.firstIndex(where: { $0.id == prevId }),
               let projIdx = self.workspaceVM.projects.firstIndex(where: { $0.id == prevProject.id }) {
                self.workspaceVM.projects[projIdx].worktrees[prevWtIdx].sideBrowserURL = self.browserURL
                self.workspaceVM.projects[projIdx].worktrees[prevWtIdx].sideBrowserTitle = self.browserTitle
                self.workspaceVM.projects[projIdx].worktrees[prevWtIdx].sideBrowserSide = self.browserSide.rawValue
                self.workspaceVM.projects[projIdx].worktrees[prevWtIdx].sideBrowserExpanded = self.browserExpanded
                self.workspaceVM.saveProjects()
            }

            if let worktree = project?.activeWorktree {
                self.previousWorktreeId = worktree.id
                self.browserURL = worktree.sideBrowserURL
                self.browserTitle = worktree.sideBrowserTitle
                if let side = BrowserSide(rawValue: worktree.sideBrowserSide) {
                    self.browserSide = side
                }
                self.browserExpanded = worktree.sideBrowserExpanded

                let worktreePath = worktree.path
                self.persistenceService.prepareForWorktree(worktree.id)
                self.historyService.load(from: worktreePath)
                self.credentialService.load(from: worktreePath)
                self.downloadService.load(from: worktreePath)
            } else {
                self.browserExpanded = false
            }
        }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
}

public enum BrowserOpenIn: String, CaseIterable, Identifiable, Codable {
    case tab = "tab"
    case leftPanel = "leftPanel"
    case rightPanel = "rightPanel"

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .tab: return "Tab"
        case .leftPanel: return "Left Panel"
        case .rightPanel: return "Right Panel"
        }
    }
}