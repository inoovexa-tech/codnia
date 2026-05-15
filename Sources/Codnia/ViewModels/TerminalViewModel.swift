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
            guard let session = TerminalSessionManager.shared.getSession(by: termId), let terminal = session.terminal else { continue }

            if !terminal.process.running {
                service.setProcessRunning(id: termId, running: false)
                if terminalProcessingStates[termId] == true {
                    workspace?.updateRunningState(for: worktreeId, isRunning: false)
                }
                terminalProcessingStates.removeValue(forKey: termId)
                terminalWorktreeMap.removeValue(forKey: termId)
            } else {
                let isActive = TerminalSessionManager.shared.isActivelyProcessing(for: termId)
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

        var env = ProcessInfo.processInfo.environment
        if env["HOME"] == nil { env["HOME"] = NSHomeDirectory() }
        if env["SHELL"] == nil { env["SHELL"] = "/bin/zsh" }
        if env["TERM"] == nil { env["TERM"] = "xterm-256color" }
        if env["LANG"] == nil { env["LANG"] = "en_US.UTF-8" }

        let (executable, args): (String, [String])
        switch type {
        case .opencode:
            executable = "/bin/zsh"
            args = ["-l", "-c", "opencode"]
        case .claude:
            executable = "/bin/zsh"
            args = ["-l", "-c", "claude"]
        case .codex:
            executable = "/bin/zsh"
            args = ["-l", "-c", "codex"]
        default:
            executable = "/bin/zsh"
            args = ["-l"]
        }

        let session = TerminalSessionManager.shared.createSession(
            cwd: cwd,
            environment: env,
            executable: executable,
            arguments: args,
            tabType: type
        )

        if let wtId = worktreeId {
            terminalWorktreeMap[session.id] = wtId
        }

        let instance = service.createTerminal(cwd: cwd, worktreeId: worktreeId, sessionId: session.id)
        if let wtId = worktreeId {
            terminalWorktreeMap[instance.id] = wtId
        }

        let tab = Tab(
            id: UUID().uuidString,
            path: instance.cwd,
            name: tabName,
            language: "",
            type: type,
            terminalId: session.id
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
            TerminalSessionManager.shared.destroySession(id: termId)
            service.kill(id: termId)
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

    public func killTerminalInstance(key: String) {
        TerminalSessionManager.shared.destroySession(id: key)
        service.kill(id: key)
    }

    func refreshSessionsForRestoredTabs(workspace: WorkspaceService?) {
        for i in tabs.indices {
            let tab = tabs[i]
            let isTerminalType = tab.type == .terminal || tab.type == .opencode || tab.type == .claude || tab.type == .codex
            guard isTerminalType, let oldId = tab.terminalId else { continue }
            if TerminalSessionManager.shared.getSession(by: oldId) != nil { continue }

            let cwd = tab.path.isEmpty ? NSHomeDirectory() : tab.path
            var env = ProcessInfo.processInfo.environment
            if env["HOME"] == nil { env["HOME"] = NSHomeDirectory() }
            if env["SHELL"] == nil { env["SHELL"] = "/bin/zsh" }
            if env["TERM"] == nil { env["TERM"] = "xterm-256color" }
            if env["LANG"] == nil { env["LANG"] = "en_US.UTF-8" }

            let (executable, args): (String, [String])
            switch tab.type {
            case .opencode: executable = "/bin/zsh"; args = ["-l", "-c", "opencode"]
            case .claude: executable = "/bin/zsh"; args = ["-l", "-c", "claude"]
            case .codex: executable = "/bin/zsh"; args = ["-l", "-c", "codex"]
            default: executable = "/bin/zsh"; args = ["-l"]
            }

            let session = TerminalSessionManager.shared.createSession(
                cwd: cwd,
                environment: env,
                executable: executable,
                arguments: args,
                tabType: tab.type
            )
            tabs[i].terminalId = session.id

            if let worktreeId = workspace?.activeProject?.activeWorktreeId {
                terminalWorktreeMap[session.id] = worktreeId
            }
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
        case .browser: return "Browser"
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
                TerminalSessionManager.shared.destroySession(id: termId)
            }
        }
        TerminalSessionManager.shared.clearAll()
    }
}