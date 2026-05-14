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
    private var terminalWorktreeMap: [String: String] = [:]
    private var terminalProcessingStates: [String: Bool] = [:]
    private var pollingTask: Task<Void, Never>?

    public init(workspace: WorkspaceService? = nil) {
        self.workspace = workspace
        service.$instances
            .receive(on: RunLoop.main)
            .sink { [weak self] inst in
                self?.instances = inst
            }
            .store(in: &cancellables)
        startPolling()
    }

    deinit {
        pollingTask?.cancel()
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await self?.checkProcessStatesIfNeeded()
            }
        }
    }

    private func checkProcessStatesIfNeeded() async {
        for (termId, worktreeId) in terminalWorktreeMap {
            guard let terminal = TerminalManager.shared.get(for: termId) else { continue }

            if !terminal.process.running {
                service.setProcessRunning(id: termId, running: false)
                if terminalProcessingStates[termId] == true {
                    workspace?.updateRunningState(for: worktreeId, isRunning: false)
                }
                terminalProcessingStates.removeValue(forKey: termId)
                terminalWorktreeMap.removeValue(forKey: termId)
            } else {
                let isActive = TerminalManager.shared.isActivelyProcessing(for: termId)
                let wasActive = terminalProcessingStates[termId] ?? false

                if isActive != wasActive {
                    service.setProcessRunning(id: termId, running: isActive)
                    workspace?.updateRunningState(for: worktreeId, isRunning: isActive)
                    terminalProcessingStates[termId] = isActive
                }
            }
        }
    }

    @discardableResult
    public func createTerminalTab(type: TabType = .terminal, name: String? = nil) -> Tab {
        let cwd = workspace?.activeProject?.activeWorktree?.path ?? NSHomeDirectory()
        let worktreeId = workspace?.activeProject?.activeWorktreeId
        let tabName = name ?? self.tabName(for: type)
        let instance = service.createTerminal(cwd: cwd, worktreeId: worktreeId)
        if let wtId = worktreeId {
            terminalWorktreeMap[instance.id] = wtId
        }
        let tab = Tab(
            id: UUID().uuidString,
            path: instance.cwd,
            name: tabName,
            language: "",
            type: type,
            terminalId: instance.id
        )
        tabs.append(tab)
        activeId = tab.id
        saveTabsToProject()
        return tab
    }

    public func setWorktreeMapping(tabs: [Tab], worktreeId: String) {
        for tab in tabs {
            if let termId = tab.terminalId {
                terminalWorktreeMap[termId] = worktreeId
            }
        }
    }

    public func closeTab(_ tab: Tab) {
        if let termId = tab.terminalId {
            if let worktreeId = terminalWorktreeMap[termId] {
                if terminalProcessingStates[termId] == true {
                    workspace?.updateRunningState(for: worktreeId, isRunning: false)
                }
                terminalProcessingStates.removeValue(forKey: termId)
                terminalWorktreeMap.removeValue(forKey: termId)
            }
            TerminalManager.shared.terminateProcess(for: termId)
            service.kill(id: termId)
            TerminalManager.shared.remove(for: termId)
        }
        tabs.removeAll { $0.id == tab.id }
        if activeId == tab.id {
            activeId = tabs.last?.id
        }
        saveTabsToProject()
    }

    public func closeTab(byId id: String) {
        if let tab = tabs.first(where: { $0.id == id }) {
            closeTab(tab)
        }
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
        case .queryResult: return "SQL Query"
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

    public func clearAllTerminals() {
        for tab in tabs {
            if let termId = tab.terminalId {
                TerminalManager.shared.remove(for: termId)
            }
        }
    }
}
