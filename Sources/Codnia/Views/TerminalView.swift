import SwiftUI
import SwiftTerm

struct TerminalView: View {
    let tab: Tab
    @EnvironmentObject var terminalVM: TerminalViewModel
    @EnvironmentObject var settings: SettingsService

    private var autoCommand: String? {
        switch tab.type {
        case .opencode: return "opencode"
        case .claude: return "claude"
        case .codex: return "codex"
        default: return nil
        }
    }

    var body: some View {
        if let termId = tab.terminalId {
            TerminalRepresentable(
                terminalId: termId,
                cwd: tab.path,
                fontSize: settings.terminalFontSize,
                autoCommand: autoCommand
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bgPrimary)
        } else {
            Text("Terminal not initialized")
                .foregroundColor(.textSecondary)
        }
    }
}

struct TerminalRepresentable: NSViewRepresentable {
    let terminalId: String
    let cwd: String
    let fontSize: Double
    var autoCommand: String? = nil

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        terminal.nativeBackgroundColor = NSColor(Color.bgPrimary)
        terminal.nativeForegroundColor = NSColor(Color.textPrimary)

        terminal.font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)

        var env = ProcessInfo.processInfo.environment
        if env["HOME"] == nil { env["HOME"] = NSHomeDirectory() }
        if env["SHELL"] == nil { env["SHELL"] = "/bin/zsh" }
        if env["TERM"] == nil { env["TERM"] = "xterm-256color" }
        if env["LANG"] == nil { env["LANG"] = "en_US.UTF-8" }
        let envStrings = env.map { "\($0.key)=\($0.value)" }

        terminal.startProcess(
            executable: "/bin/zsh",
            args: ["-l"],
            environment: envStrings,
            execName: nil,
            currentDirectory: cwd.isEmpty ? nil : cwd
        )

        if let command = autoCommand {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                terminal.feed(text: command + "\n")
            }
        }

        context.coordinator.terminal = terminal
        context.coordinator.setupFirstResponder()

        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        nsView.font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        weak var terminal: LocalProcessTerminalView?

        func setupFirstResponder() {
            DispatchQueue.main.async { [weak self] in
                self?.tryMakeFirstResponder()
            }

            NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.tryMakeFirstResponder()
            }
        }

        private func tryMakeFirstResponder() {
            guard let terminal = terminal else { return }
            guard let window = terminal.window ?? NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow else { return }
            window.makeFirstResponder(terminal)
        }
    }
}
