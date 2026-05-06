import SwiftUI
import SwiftTerm

@MainActor
class TerminalManager {
    static let shared = TerminalManager()
    private var terminals: [String: LocalProcessTerminalView] = [:]

    func get(for id: String) -> LocalProcessTerminalView? {
        terminals[id]
    }

    func set(_ terminal: LocalProcessTerminalView, for id: String) {
        terminals[id] = terminal
    }

    func remove(for id: String) {
        terminals.removeValue(forKey: id)?.removeFromSuperview()
    }

    func show(id: String) {
        guard let terminal = terminals[id] else { return }
        terminal.superview?.subviews.forEach { $0.isHidden = true }
        terminal.isHidden = false
        if let window = terminal.window ?? NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            _ = window.makeFirstResponder(terminal)
        }
    }
}

// Global container that persists across SwiftUI view recreation
@MainActor
class TerminalContainerManager {
    static let shared = TerminalContainerManager()
    private var container: NSView?

    func getContainer() -> NSView {
        if let existing = container, existing.window != nil {
            return existing
        }
        let newContainer = NSView()
        newContainer.autoresizingMask = [.width, .height]
        container = newContainer
        return newContainer
    }
}

struct TerminalHostView: NSViewRepresentable {
    @Binding var tabs: [Tab]
    @Binding var activeTabId: String?
    let fontSize: Double

    func makeNSView(context: Context) -> NSView {
        let container = TerminalContainerManager.shared.getContainer()
        // Ensure container is properly sized when added to view hierarchy
        DispatchQueue.main.async {
            if let superview = container.superview {
                container.frame = superview.bounds
            }
        }
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Ensure all terminal tabs have a view in the container
        for tab in tabs {
            guard let termId = tab.terminalId else { continue }
            if let existing = TerminalManager.shared.get(for: termId) {
                // Re-add to container if needed
                if existing.superview == nil {
                    nsView.addSubview(existing)
                    existing.frame = nsView.bounds
                    existing.autoresizingMask = [.width, .height]
                }
            } else {
                let terminal = createTerminal(cwd: tab.path, fontSize: fontSize, type: tab.type, in: nsView)
                TerminalManager.shared.set(terminal, for: termId)
            }
        }

        // Show active terminal
        if let activeTab = tabs.first(where: { $0.id == activeTabId }),
           let termId = activeTab.terminalId {
            TerminalManager.shared.show(id: termId)
        }
    }

    private func createTerminal(cwd: String, fontSize: Double, type: TabType, in container: NSView) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: container.bounds)
        terminal.autoresizingMask = [.width, .height]
        terminal.nativeBackgroundColor = NSColor(Color.bgPrimary)
        terminal.nativeForegroundColor = NSColor(Color.textPrimary)
        terminal.font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        terminal.isHidden = true

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

        let autoCommand: String? = {
            switch type {
            case .opencode: return "opencode"
            case .claude: return "claude"
            case .codex: return "codex"
            default: return nil
            }
        }()

        if let command = autoCommand {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                terminal.feed(text: command + "\n")
            }
        }

        container.addSubview(terminal)
        return terminal
    }
}

struct TerminalView: View {
    @Binding var tabs: [Tab]
    @Binding var activeTabId: String?
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        TerminalHostView(
            tabs: $tabs,
            activeTabId: $activeTabId,
            fontSize: settings.terminalFontSize
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}
