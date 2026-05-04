import SwiftUI
import SwiftTerm

struct TerminalView: View {
    let tab: Tab
    @EnvironmentObject var terminalVM: TerminalViewModel
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        TerminalRepresentable(
            cwd: tab.path,
            shell: "/bin/zsh"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}

struct TerminalRepresentable: NSViewRepresentable {
    let cwd: String
    let shell: String

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        terminal.nativeBackgroundColor = NSColor(Color.bgPrimary)
        terminal.nativeForegroundColor = NSColor(Color.textPrimary)

        let font = NSFont(name: "SF Mono", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminal.font = font

        let home = NSHomeDirectory()
        var env: [String] = []
        for (key, value) in ProcessInfo.processInfo.environment {
            env.append("\(key)=\(value)")
        }
        env.append("PATH=/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin")

        terminal.startProcess(
            executable: shell,
            args: ["-l"],
            environment: env,
            execName: nil,
            currentDirectory: cwd.isEmpty ? nil : cwd
        )

        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Resize/font updates can be handled here
    }
}
