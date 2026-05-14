import SwiftUI
import Combine

@MainActor
public final class TerminalViewModel: ObservableObject {
    @Published public var tabs: [Tab] = []
    @Published public var activeId: String? = nil
    @Published public var instances: [TerminalInstance] = []

    private let service = TerminalService()
    private var cancellables = Set<AnyCancellable>()
    var workspace: WorkspaceService?

    public init(workspace: WorkspaceService? = nil) {
        self.workspace = workspace
        // Bridge service instances to tabs
        service.$instances
            .receive(on: RunLoop.main)
            .sink { [weak self] inst in
                self?.instances = inst
            }
            .store(in: &cancellables)
    }

    @discardableResult
    public func createTerminalTab(type: TabType = .terminal) -> Tab {
        let cwd = workspace?.activeProject?.activeWorktree?.path ?? NSHomeDirectory()
        let name = tabName(for: type)
        let instance = service.createTerminal(cwd: cwd)
        let tab = Tab(
            id: UUID().uuidString,
            path: instance.cwd,
            name: name,
            language: "",
            type: type,
            terminalId: instance.id
        )
        tabs.append(tab)
        activeId = tab.id
        saveTabsToProject()
        return tab
    }

    public func closeTab(_ tab: Tab) {
        if let termId = tab.terminalId {
            service.kill(id: termId)
            TerminalManager.shared.remove(for: termId)
        }
        tabs.removeAll { $0.id == tab.id }
        saveTabsToProject()
    }

    public func closeTab(byId id: String) {
        if let tab = tabs.first(where: { $0.id == id }) {
            closeTab(tab)
        }
    }

    public func killTerminalInstance(key: String) {
        service.kill(id: key)
        TerminalManager.shared.remove(for: key)
    }

    private func tabName(for type: TabType) -> String {
        switch type {
        case .opencode: return "OpenCode"
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .terminal: return "Terminal"
        case .file: return "Terminal"
        case .diff: return "Terminal"
        case .image: return "Image Viewer"
        case .pdf: return "PDF Viewer"
        }
    }

    private func saveTabsToProject() {
        guard let workspace = workspace,
              let project = workspace.activeProject,
              let worktreeId = project.activeWorktreeId,
              let projIdx = workspace.projects.firstIndex(where: { $0.id == project.id }),
              let wtIdx = workspace.projects[projIdx].worktrees.firstIndex(where: { $0.id == worktreeId }) else { return }

        workspace.projects[projIdx].worktrees[wtIdx].terminalTabs = tabs
        workspace.projects[projIdx].worktrees[wtIdx].activeTabId = activeId
        workspace.saveProjects()
    }

    public func moveTab(from source: Int, to destination: Int) {
        guard source < tabs.count, destination < tabs.count, source != destination else { return }
        let tab = tabs.remove(at: source)
        let adjustedDestination = source < destination ? destination - 1 : destination
        tabs.insert(tab, at: adjustedDestination)
        saveTabsToProject()
    }
}
