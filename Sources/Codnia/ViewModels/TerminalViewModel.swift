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
    public func createTerminalTab(type: TabType = .terminal, command: String? = nil) -> Tab {
        let cwd = service.instances.first?.cwd ?? NSHomeDirectory()
        let name = command.map { commandName($0) } ?? "Terminal"
        let instance = service.createTerminal(cwd: cwd, command: command)
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

    public func writeToTerminal(id: String, data: String) {
        if let tab = tabs.first(where: { $0.id == id }),
           let termId = tab.terminalId {
            service.write(id: termId, data: data)
        }
    }

    public func getProcessHandle(forTerminalId id: String) -> FileHandle? {
        // Bridge to raw terminal process for SwiftTerm
        return service.getOutputHandle(id: id.replacingOccurrences(of: "terminal-", with: ""))
    }

    private func commandName(_ cmd: String) -> String {
        switch cmd {
        case "opencode": return "OpenCode"
        case "claude": return "Claude Code"
        case "codex": return "Codex"
        default: return cmd.capitalized
        }
    }
}
