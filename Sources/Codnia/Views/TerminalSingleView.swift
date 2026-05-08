import SwiftUI
import SwiftTerm
import AppKit

struct TerminalSingleView: View {
    let terminalId: String
    let fontSize: Double

    var body: some View {
        TerminalSingleContainerView(terminalId: terminalId, fontSize: fontSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bgPrimary)
    }
}

class TerminalSplitContainer: NSView {
    var terminalId: String?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, let id = terminalId, let term = TerminalManager.shared.get(for: id) {
            term.frame = bounds
            term.needsDisplay = true
            term.displayIfNeeded()
        }
    }

    override func layout() {
        super.layout()
        subviews.forEach {
            $0.frame = bounds
            $0.needsDisplay = true
        }
    }
}

struct TerminalSingleContainerView: NSViewRepresentable {
    let terminalId: String
    let fontSize: Double

    func makeNSView(context: Context) -> NSView {
        let container = TerminalSplitContainer()
        container.terminalId = terminalId
        container.autoresizingMask = [.width, .height]

        if let existingTerminal = TerminalManager.shared.get(for: terminalId) {
            existingTerminal.isHidden = false
            existingTerminal.removeFromSuperview()
            container.addSubview(existingTerminal)
            existingTerminal.autoresizingMask = [.width, .height]
            existingTerminal.needsDisplay = true
            DispatchQueue.main.async {
                existingTerminal.frame = container.bounds
                existingTerminal.needsDisplay = true
                existingTerminal.displayIfNeeded()
            }
        } else {
            createTerminal(in: container)
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let terminal = TerminalManager.shared.get(for: terminalId) else { return }
        if terminal.superview != nsView {
            terminal.removeFromSuperview()
            nsView.addSubview(terminal)
            terminal.autoresizingMask = [.width, .height]
        }
        terminal.frame = nsView.bounds
        terminal.needsDisplay = true
    }

    private func createTerminal(in container: NSView) {
        let terminal = LocalProcessTerminalView(frame: container.bounds)
        terminal.autoresizingMask = [.width, .height]
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
            currentDirectory: NSHomeDirectory()
        )

        TerminalManager.shared.set(terminal, for: terminalId)
        container.addSubview(terminal)
    }
}
