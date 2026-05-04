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
