import Foundation
import AppKit

@MainActor
final class TerminalSession: ObservableObject, Identifiable {
    let id: String
    let createdAt: Date

    @Published var viewIds: Set<UUID> = []
    @Published var isActive: Bool = true
    @Published var isDestroyed: Bool = false

    var terminal: CodniaTerminalView?
    let cwd: String
    let environment: [String: String]
    let executable: String
    let arguments: [String]
    let tabType: TabType

    private(set) var refCount: Int = 0

    init(id: String = UUID().uuidString,
         terminal: CodniaTerminalView? = nil,
         cwd: String,
         environment: [String: String],
         executable: String = "/bin/zsh",
         arguments: [String] = ["-l"],
         tabType: TabType = .terminal) {
        self.id = id
        self.terminal = terminal
        self.cwd = cwd
        self.environment = environment
        self.executable = executable
        self.arguments = arguments
        self.tabType = tabType
        self.createdAt = Date()
    }

    func addView(_ viewId: UUID) {
        viewIds.insert(viewId)
        refCount = viewIds.count
    }

    func removeView(_ viewId: UUID) {
        viewIds.remove(viewId)
        refCount = viewIds.count
    }

    var hasViews: Bool {
        !viewIds.isEmpty
    }

    var isProcessRunning: Bool {
        terminal?.process.running ?? false
    }

    func sendText(_ text: String) {
        guard let terminal = terminal else { return }
        terminal.send(txt: text)
    }

    func terminate() {
        guard let terminal = terminal, let process = terminal.process else { return }
        let pgid = process.shellPid
        guard pgid > 0 else {
            terminal.terminate()
            return
        }

        // SwiftTerm's terminate sends SIGTERM only to the shell PID (not the process group)
        terminal.terminate()

        // Send SIGTERM to the entire process group — kills child processes like dev servers
        killpg(pgid, SIGTERM)

        // SIGKILL fallback after delay ensures orphaned or stuck processes are cleaned up
        Task.detached { [pgid] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            killpg(pgid, SIGKILL)
        }
    }

    func focus() {
        guard let terminal = terminal else { return }
        if let window = terminal.window ?? NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            _ = window.makeFirstResponder(terminal)
        }
    }
}

struct ViewportState: Codable {
    var scrollOffset: CGFloat = 0
    var selectionRange: String? = nil

    init() {}
}