import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    public let workspaceVM: WorkspaceService
    public let settings: SettingsService
    public let searchVM: SearchService
    public let terminalVM: TerminalViewModel
    public let editorVM: EditorViewModel
    @Published public var showGlobalSearch: Bool = false
    @Published var leftSidebarExpanded: Bool = true
    @Published var rightSidebarExpanded: Bool = false
    @Published var rightSidebarTab: RightSidebarTab = .explorer
    @Published var activityBarWidth: CGFloat = 320
    @Published var leftSidebarWidth: CGFloat = 220

    public init() {
        let ws = WorkspaceService()
        let s = SettingsService()
        let sr = SearchService()
        let tm = TerminalViewModel()
        let ed = EditorViewModel(workspace: ws, settings: s, terminal: tm)
        self.workspaceVM = ws
        self.settings = s
        self.searchVM = sr
        self.terminalVM = tm
        self.editorVM = ed
    }
}
