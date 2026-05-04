import SwiftUI
import SwiftTerm

struct TerminalView: View {
    let tab: Tab
    @EnvironmentObject var terminalVM: TerminalViewModel
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        TerminalRepresentable(
            cwd: tab.path,
            shell: "/bin/zsh",
            fontSize: settings.terminalFontSize,
            onInput: { [weak terminalVM] data in
                // Bridge handled via NSViewRepresentable
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}

struct TerminalRepresentable: NSViewRepresentable {
    let cwd: String
    let shell: String
    let fontSize: Double
    let onInput: (String) -> Void

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView()
        terminal.nativeBackgroundColor = NSColor(Color.bgPrimary)
        terminal.nativeForegroundColor = NSColor(Color.textPrimary)

        if let font = NSFont(name: "SF Mono", size: CGFloat(fontSize)) {
            terminal.font = font
        } else {
            terminal.font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        }

        // Set ANSI colors to match xterm.js theme from original app
        let t = terminal.getTerminal()
        let palette = Colors()
        palette.setColor(.black, NSColor(Color.bgPrimary))
        palette.setColor(.red, NSColor(hex: "#cd3131"))
        palette.setColor(.green, NSColor(hex: "#0dbc79"))
        palette.setColor(.yellow, NSColor(hex: "#e5e510"))
        palette.setColor(.blue, NSColor(hex: "#2472c8"))
        palette.setColor(.magenta, NSColor(hex: "#bc3fbc"))
        palette.setColor(.cyan, NSColor(hex: "#11a8cd"))
        palette.setColor(.white, NSColor(hex: "#e5e5e5"))
        palette.setColor(.brightBlack, NSColor(hex: "#666666"))
        palette.setColor(.brightRed, NSColor(hex: "#f14c4c"))
        palette.setColor(.brightGreen, NSColor(hex: "#23d18b"))
        palette.setColor(.brightYellow, NSColor(hex: "#f5f543"))
        palette.setColor(.brightBlue, NSColor(hex: "#3b8eea"))
        palette.setColor(.brightMagenta, NSColor(hex: "#d670d6"))
        palette.setColor(.brightCyan, NSColor(hex: "#29b8db"))
        palette.setColor(.brightWhite, NSColor.white)
        t.setColors(palette)

        // Build PATH
        let home = NSHomeDirectory()
        let pathComponents = [
            "\(home)/.local/bin",
            "\(home)/.cargo/bin",
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        let env = ProcessInfo.processInfo.environment.merging(
            ["PATH": pathComponents.joined(separator: ":")],
            uniquingKeysWith: { current, new in current.isEmpty ? new : current }
        )

        terminal.startProcess(
            executable: shell,
            args: ["-l"],
            environment: env,
            execName: nil
        )

        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Resize/font updates can be handled here
    }
}

// Helper for hex colors in NSColor
private extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = (int >> 16) & 0xFF
        let g = (int >> 8) & 0xFF
        let b = int & 0xFF
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: 1.0
        )
    }
}
