import SwiftUI
import Combine

@MainActor
public final class TerminalViewModel: ObservableObject {
    @Published public var tabs: [Tab] = []
    @Published public var activeId: String? = nil
    @Published public var instances: [TerminalInstance] = []

    private let service = TerminalService()
    private var cancellables = Set<AnyCancellable>()

    public init() {
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
        let cwd = service.instances.first?.cwd ?? NSHomeDirectory()
        let name = tabName(for: type)
        let instance = service.createTerminal(cwd: cwd)
        let tab = Tab(
            id: "terminal-\(instance.id)",
            path: instance.cwd,
            name: name,
            language: "",
            type: type,
            terminalId: instance.id
        )
        tabs.append(tab)
        activeId = tab.id
        return tab
    }

    public func closeTab(_ tab: Tab) {
        if let termId = tab.terminalId {
            service.kill(id: termId)
        }
        tabs.removeAll { $0.id == tab.id }
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
        }
    }
}
