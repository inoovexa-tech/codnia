import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    @Published public var editorVM: EditorViewModel
    @Published public var workspaceVM: WorkspaceService
    @Published public var terminalVM: TerminalViewModel
    @Published public var settings: SettingsService
    @Published public var searchVM: SearchService
    @Published public var showGlobalSearch: Bool = false

    public init() {
        self.workspaceVM = WorkspaceService()
        self.settings = SettingsService()
        self.searchVM = SearchService()
        self.terminalVM = TerminalViewModel()
        self.editorVM = EditorViewModel(
            workspace: self.workspaceVM,
            settings: self.settings,
            terminal: self.terminalVM
        )
    }
}
