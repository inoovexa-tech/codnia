import SwiftUI
import Combine

@MainActor
public final class SplitViewModel: ObservableObject {
    @Published public var root: SplitPane = .leaf(SplitLeaf())
    @Published public var activePaneId: UUID?

    private var tabSplitRoots: [String: SplitPane] = [:]
    private var tabActivePaneIds: [String: UUID] = [:]
    private var currentTabId: String?

    public init() {}

    // MARK: - Tab Switching

    public func switchToTab(_ tabId: String?, terminalVM: TerminalViewModel) {
        guard tabId != currentTabId else { return }

        for leafId in root.allLeafIds {
            guard let leaf = root.findLeaf(id: leafId),
                  let sessionId = leaf.sessionId,
                  let session = TerminalSessionManager.shared.getSession(by: sessionId) else { continue }
            session.saveViewportState()
        }

        if let currentId = currentTabId {
            tabSplitRoots[currentId] = root
            tabActivePaneIds[currentId] = activePaneId
        }

        currentTabId = tabId

        if let tabId = tabId, let savedRoot = tabSplitRoots[tabId] {
            root = savedRoot
            activePaneId = tabActivePaneIds[tabId]
            if activePaneId == nil || !root.allLeafIds.contains(activePaneId!) {
                activePaneId = root.allLeafIds.first
            }
            root = root.mapLeafTabIds(to: tabId)

            // Restore terminal session bindings for each split leaf
            if let tab = terminalVM.tabs.first(where: { $0.id == tabId }),
               (tab.type == .terminal || tab.type == .opencode || tab.type == .claude || tab.type == .codex) {
                for leafId in root.allLeafIds {
                    guard let leaf = root.findLeaf(id: leafId) else { continue }
                    if let sessionId = leaf.sessionId,
                       TerminalSessionManager.shared.getSession(by: sessionId) != nil {
                        TerminalSessionManager.shared.registerView(leafId, to: sessionId)
                    } else if let terminalId = tab.terminalId {
                        root.mutateLeaf(id: leafId) { leaf in
                            leaf.terminalId = terminalId
                            leaf.sessionId = terminalId
                        }
                        TerminalSessionManager.shared.registerView(leafId, to: terminalId)
                    }
                }
            }
        } else if let tabId = tabId {
            root = .leaf(SplitLeaf(tabId: tabId))
            activePaneId = root.allLeafIds.first

            // Initialize terminal session for terminal tabs
            if let tab = terminalVM.tabs.first(where: { $0.id == tabId }),
               (tab.type == .terminal || tab.type == .opencode || tab.type == .claude || tab.type == .codex),
               let terminalId = tab.terminalId,
               let paneId = activePaneId {
                root.mutateLeaf(id: paneId) { leaf in
                    leaf.terminalId = terminalId
                    leaf.sessionId = terminalId
                }
                TerminalSessionManager.shared.registerView(paneId, to: terminalId)
            }
        } else {
            root = .leaf(SplitLeaf())
            activePaneId = nil
        }
    }

    public func removeTabState(_ tabId: String) {
        tabSplitRoots.removeValue(forKey: tabId)
        tabActivePaneIds.removeValue(forKey: tabId)
        if currentTabId == tabId {
            currentTabId = nil
        }
    }

    func destroyTerminalSessions(for tabId: String) {
        guard let root = tabSplitRoots[tabId] else { return }
        for leafId in root.allLeafIds {
            guard let leaf = root.findLeaf(id: leafId), let sessionId = leaf.sessionId else { continue }
            TerminalSessionManager.shared.destroySession(id: sessionId)
        }
        removeTabState(tabId)
    }

    // MARK: - Worktree Persistence

    public func saveToWorktree(_ worktree: inout Worktree) {
        if let currentId = currentTabId {
            tabSplitRoots[currentId] = root
            tabActivePaneIds[currentId] = activePaneId
        }
        worktree.tabSplitRoots = tabSplitRoots
        worktree.tabActivePaneIds = tabActivePaneIds
    }

    public func loadFromWorktree(_ worktree: Worktree) {
        tabSplitRoots = worktree.tabSplitRoots
        tabActivePaneIds = worktree.tabActivePaneIds
        currentTabId = nil
    }

    public func resetState() {
        root = .leaf(SplitLeaf())
        activePaneId = nil
        tabSplitRoots = [:]
        tabActivePaneIds = [:]
        currentTabId = nil
    }

    // MARK: - Split Operations

    public func splitPane(_ paneId: UUID, direction: SplitDirection,
                          editorVM: EditorViewModel, terminalVM: TerminalViewModel) {
        guard let leaf = root.findLeaf(id: paneId), let tabId = leaf.tabId else { return }

        let someTabs = editorVM.tabs + terminalVM.tabs
        guard let tab = someTabs.first(where: { $0.id == tabId }) else { return }
        if tab.type == .browser { return }

        let isTerminalType = tab.type == .terminal || tab.type == .opencode || tab.type == .claude || tab.type == .codex
        let existingSessionId = leaf.sessionId

        let containerId = UUID()
        let newLeaf: SplitLeaf
        if isTerminalType {
            newLeaf = SplitLeaf(id: UUID(), tabId: tabId)
        } else {
            newLeaf = SplitLeaf(id: UUID(), tabId: tabId, terminalId: leaf.terminalId, sessionId: existingSessionId)
        }

        let split: SplitPane
        let newActiveId: UUID
        switch direction {
        case .horizontal:
            split = .split(SplitContainer(
                id: containerId,
                direction: direction,
                first: .leaf(SplitLeaf(id: leaf.id, tabId: leaf.tabId, terminalId: leaf.terminalId, sessionId: existingSessionId)),
                second: .leaf(newLeaf),
                proportion: 0.5
            ))
            newActiveId = newLeaf.id
        case .vertical:
            split = .split(SplitContainer(
                id: containerId,
                direction: direction,
                first: .leaf(newLeaf),
                second: .leaf(SplitLeaf(id: leaf.id, tabId: leaf.tabId, terminalId: leaf.terminalId, sessionId: existingSessionId)),
                proportion: 0.5
            ))
            newActiveId = newLeaf.id
        }

        root = root.replacingLeaf(id: paneId, with: split)
        setContainerProportion(containerId, 0.5)
        activePaneId = newActiveId

        if isTerminalType {
            var env = ProcessInfo.processInfo.environment
            if env["HOME"] == nil { env["HOME"] = NSHomeDirectory() }
            if env["SHELL"] == nil { env["SHELL"] = "/bin/zsh" }
            if env["TERM"] == nil { env["TERM"] = "xterm-256color" }
            if env["LANG"] == nil { env["LANG"] = "en_US.UTF-8" }

            let cmd = terminalCommand(for: tab.type)
            let cwd = tab.path.isEmpty ? NSHomeDirectory() : tab.path

            let newSession = TerminalSessionManager.shared.createSession(
                cwd: cwd,
                environment: env,
                executable: cmd.executable,
                arguments: cmd.args,
                tabType: tab.type
            )
            TerminalSessionManager.shared.registerView(newLeaf.id, to: newSession.id)

            root.mutateLeaf(id: newLeaf.id) { leaf in
                leaf.sessionId = newSession.id
                leaf.terminalId = newSession.id
            }

            if let sessionId = existingSessionId {
                TerminalSessionManager.shared.registerView(leaf.id, to: sessionId)
            }
        }
    }

    public func splitActivePane(_ direction: SplitDirection,
                                editorVM: EditorViewModel, terminalVM: TerminalViewModel) {
        guard let paneId = activePaneId else { return }
        splitPane(paneId, direction: direction, editorVM: editorVM, terminalVM: terminalVM)
    }

    public func closePane(_ paneId: UUID,
                          editorVM: EditorViewModel, terminalVM: TerminalViewModel) {
        guard let closingLeaf = root.findLeaf(id: paneId) else { return }

        let saveTabId = closingLeaf.tabId
        let someTabs = editorVM.tabs + terminalVM.tabs
        let closingTab: Tab? = saveTabId.flatMap { id in someTabs.first { $0.id == id } }
        let isTerminalType = closingTab.map {
            $0.type == .terminal || $0.type == .opencode || $0.type == .claude || $0.type == .codex
        } ?? false

        if isTerminalType {
            TerminalSessionManager.shared.unregisterView(paneId)
        }

        if let newRoot = root.removingLeaf(id: paneId) {
            root = newRoot
        } else {
            root = .leaf(SplitLeaf())
        }

        let ids = root.allLeafIds
        if activePaneId == paneId || !ids.contains(activePaneId ?? UUID()) {
            activePaneId = ids.first
        }

        let stillReferenced = saveTabId.map { id in
            root.allLeafIds.contains { leafId in
                root.findLeaf(id: leafId)?.tabId == id
            }
        } ?? false

        if let tid = saveTabId, !stillReferenced, let tab = closingTab {
            if editorVM.tabs.contains(where: { $0.id == tid }) {
                editorVM.closeTab(tid)
            } else if terminalVM.tabs.contains(where: { $0.id == tid }) {
                terminalVM.closeTab(tab)
            }
            removeTabState(tid)
        }

        if let firstId = ids.first, let firstLeaf = root.findLeaf(id: firstId), let tid = firstLeaf.tabId {
            if editorVM.tabs.contains(where: { $0.id == tid }) {
                editorVM.activateTab(tid)
            } else {
                editorVM.activeTabId = tid
            }
        }

        redrawAllTerminals()
    }

    private func terminalCommand(for type: TabType) -> (executable: String, args: [String]) {
        switch type {
        case .opencode: return ("/bin/zsh", ["-l", "-c", "opencode"])
        case .claude: return ("/bin/zsh", ["-l", "-c", "claude"])
        case .codex: return ("/bin/zsh", ["-l", "-c", "codex"])
        default: return ("/bin/zsh", ["-l"])
        }
    }

    private func redrawAllTerminals() {
        for (_, session) in TerminalSessionManager.shared.getAll() {
            session.terminal?.needsDisplay = true
            session.terminal?.displayIfNeeded()
        }
    }

    public func setContainerProportion(_ id: UUID, _ proportion: CGFloat) {
        root.mutateContainer(id: id) { container in
            container.proportion = proportion
        }
    }

    public func setActivePaneTab(_ tabId: String?, terminalVM: TerminalViewModel? = nil) {
        let paneId = activePaneId ?? root.allLeafIds.first
        guard let id = paneId else { return }
        activePaneId = id
        root.mutateLeaf(id: id) { leaf in
            leaf.tabId = tabId
            if let tid = tabId, let vm = terminalVM {
                leaf.terminalId = vm.tabs.first { $0.id == tid }?.terminalId
            }
            if let tid = tabId, let vm = terminalVM, let tab = vm.tabs.first(where: { $0.id == tid }),
               let terminalId = tab.terminalId {
                let isTerminal = tab.type == .terminal || tab.type == .opencode || tab.type == .claude || tab.type == .codex
                if isTerminal {
                    leaf.sessionId = terminalId
                    TerminalSessionManager.shared.registerView(leaf.id, to: terminalId)
                }
            }
        }
    }

    public func setActivePaneSession(_ sessionId: String?, viewId: UUID? = nil) {
        let paneId = viewId ?? activePaneId ?? root.allLeafIds.first
        guard let id = paneId else { return }
        root.mutateLeaf(id: id) { leaf in
            leaf.sessionId = sessionId
        }
    }
}