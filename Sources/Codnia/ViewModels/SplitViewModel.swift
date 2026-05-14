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

        let containerId = UUID()
        let newLeaf = SplitLeaf(id: UUID(), tabId: tabId)
        let split = SplitPane.split(SplitContainer(
            id: containerId,
            direction: direction,
            first: .leaf(SplitLeaf(id: leaf.id, tabId: leaf.tabId)),
            second: .leaf(newLeaf),
            proportion: 0.65
        ))

        root = root.replacingLeaf(id: paneId, with: split)
        setContainerProportion(containerId, 0.65)
        activePaneId = leaf.id
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
        let closingTab: Tab? = saveTabId.flatMap { id in someTabs.first(where: { $0.id == id }) }
        let isTerminalType = closingTab.map {
            $0.type == .terminal || $0.type == .opencode || $0.type == .claude || $0.type == .codex
        } ?? false

        if isTerminalType {
            terminalVM.killTerminalInstance(key: paneId.uuidString)
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
    }

    public func setContainerProportion(_ id: UUID, _ proportion: CGFloat) {
        root.mutateContainer(id: id) { container in
            container.proportion = proportion
        }
    }

    public func setActivePaneTab(_ tabId: String?) {
        let paneId = activePaneId ?? root.allLeafIds.first
        guard let id = paneId else { return }
        activePaneId = id
        root.mutateLeaf(id: id) { leaf in
            leaf.tabId = tabId
        }
    }
}
