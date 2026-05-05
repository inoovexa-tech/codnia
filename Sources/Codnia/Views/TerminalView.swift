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

        let font = NSFont(name: "SF Mono", size: CGFloat(fontSize)) ?? NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        terminal.font = font

        var env: [String] = []
        for (key, value) in ProcessInfo.processInfo.environment {
            env.append("\(key)=\(value)")
        }
        env.append("PATH=/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin")

        terminal.startProcess(
            executable: "/bin/zsh",
            args: ["-l"],
            environment: env,
            execName: nil,
            currentDirectory: cwd.isEmpty ? nil : cwd
        )

        if let command = autoCommand {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                terminal.feed(text: command + "\n")
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = terminal.window {
                window.makeFirstResponder(terminal)
            }
        }

        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        if let font = NSFont(name: "SF Mono", size: CGFloat(fontSize)) {
            nsView.font = font
        }
    }
}
