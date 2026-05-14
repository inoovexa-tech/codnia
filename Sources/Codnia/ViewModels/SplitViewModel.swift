import SwiftUI
import Combine

@MainActor
public final class SplitViewModel: ObservableObject {
    @Published public var root: SplitPane = .leaf(SplitLeaf())
    @Published public var activePaneId: UUID?

    public init() {}

    public func splitPane(_ paneId: UUID, direction: SplitDirection,
                          editorVM: EditorViewModel, terminalVM: TerminalViewModel) {
        guard let leaf = root.findLeaf(id: paneId), let tabId = leaf.tabId else { return }

        let someTabs = editorVM.tabs + terminalVM.tabs
        guard let tab = someTabs.first(where: { $0.id == tabId }) else { return }

        let isTerminalType = tab.type == .terminal || tab.type == .opencode || tab.type == .claude || tab.type == .codex
        let existingSessionId = leaf.sessionId

        let containerId = UUID()
        let newLeaf = SplitLeaf(id: UUID(), tabId: tabId, terminalId: leaf.terminalId, sessionId: existingSessionId)

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

if isTerminalType, let sessionId = existingSessionId {
            print("[SPLIT] Registering original leaf \(leaf.id) to session \(sessionId)")
            TerminalSessionManager.shared.registerView(leaf.id, to: sessionId)
            print("[SPLIT] Registering new leaf \(newLeaf.id) to session \(sessionId)")
            TerminalSessionManager.shared.registerView(newLeaf.id, to: sessionId)
            if let session = TerminalSessionManager.shared.getSession(by: sessionId) {
                print("[SPLIT] Session \(sessionId) has terminal: \(session.terminal != nil)")
                print("[SPLIT] Session viewIds: \(session.viewIds)")
            } else {
                print("[SPLIT] Session \(sessionId) not found!")
            }
        } else {
            print("[SPLIT] Not terminal type or no sessionId. isTerminalType: \(isTerminalType), existingSessionId: \(existingSessionId ?? "nil")")
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
            // For terminal tabs, set sessionId from tab.terminalId (which IS the session id)
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