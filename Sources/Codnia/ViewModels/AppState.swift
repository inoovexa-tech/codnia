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
    @Published var rightSidebarExpanded: Bool = false
    @Published var rightSidebarTab: RightSidebarTab = .explorer
    @Published var showGlobalSearchModal: Bool = false

    @Published var leftBrowserExpanded: Bool = false
    @Published var rightBrowserExpanded: Bool = false
    @Published var leftBrowserURL: String = ""
    @Published var rightBrowserURL: String = ""
    @Published var leftBrowserTitle: String = ""
    @Published var rightBrowserTitle: String = ""
    public init() {
        let ws = WorkspaceService()
        let s = SettingsService()
        let sr = SearchService()
        let ps = PluginService()
        let tm = TerminalViewModel()
        let ed = EditorViewModel(workspace: ws, settings: s, terminal: tm)
        let gv = GitViewModel(workspace: ws, editorVM: ed)
        let sp = SplitViewModel()
        let tv = TasksViewModel(workspace: ws)
        let db = DatabaseConnectionService()
        let nv = NotesViewModel()
        let bs = BrowserService()
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

        bs.editorVM = ed
        bs.settings = s

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

        bs.appState = self
    }

    public func openURL(_ urlString: String, in location: BrowserOpenIn) {
        switch location {
        case .tab:
            editorVM.openURL(urlString)
        case .leftPanel:
            leftBrowserURL = urlString
            leftBrowserExpanded = true
        case .rightPanel:
            rightBrowserURL = urlString
            rightBrowserExpanded = true
        }
    }
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