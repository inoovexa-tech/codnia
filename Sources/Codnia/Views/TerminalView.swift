import SwiftUI
import SwiftTerm

class CodniaTerminalView: LocalProcessTerminalView {
    var onDataReceived: ((Int) -> Void)?

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        onDataReceived?(slice.count)
    }
}

@MainActor
class TerminalManager {
    static let shared = TerminalManager()
    private var terminals: [String: CodniaTerminalView] = [:]
    private var bytesSinceLastPoll: [String: Int] = [:]
    private var lastActiveTimes: [String: Date] = [:]

    func get(for id: String) -> CodniaTerminalView? {
        terminals[id]
    }

    func set(_ terminal: CodniaTerminalView, for id: String) {
        terminals[id] = terminal
        terminal.onDataReceived = { [weak self] byteCount in
            DispatchQueue.main.async {
                self?.recordBytes(for: id, bytes: byteCount)
            }
        }
    }

    func remove(for id: String) {
        terminals.removeValue(forKey: id)?.removeFromSuperview()
        bytesSinceLastPoll.removeValue(forKey: id)
        lastActiveTimes.removeValue(forKey: id)
    }

    func show(id: String) {
        guard let terminal = terminals[id] else { return }
        terminal.superview?.subviews.forEach { $0.isHidden = true }
        terminal.isHidden = false
        if let window = terminal.window ?? NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            _ = window.makeFirstResponder(terminal)
        }
    }

    func getAllTerminals() -> [CodniaTerminalView] {
        Array(terminals.values)
    }

    func terminateProcess(for id: String) {
        terminals[id]?.terminate()
    }

    func isProcessRunning(for id: String) -> Bool {
        terminals[id]?.process.running ?? false
    }

    func sendText(id: String, text: String) {
        guard let terminal = terminals[id] else { return }
        terminal.feed(byteArray: ArraySlice([UInt8](text.utf8)))
    }

    private func recordBytes(for id: String, bytes: Int) {
        bytesSinceLastPoll[id] = (bytesSinceLastPoll[id] ?? 0) + bytes
    }

    func isActivelyProcessing(for id: String) -> Bool {
        let bytes = bytesSinceLastPoll[id] ?? 0
        bytesSinceLastPoll[id] = nil

        if bytes >= 150 {
            lastActiveTimes[id] = Date()
            return true
        }

        if let lastActive = lastActiveTimes[id], Date().timeIntervalSince(lastActive) < 3.0 {
            return true
        }

        return false
    }
}

@MainActor
class TerminalEventMonitor {
    static let shared = TerminalEventMonitor()
    private var monitor: Any?

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self else { return event }
            let result = self.handle(event)
            return result ? nil : event
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        let mouseLocation = NSEvent.mouseLocation
        for terminal in TerminalManager.shared.getAllTerminals() {
            guard !terminal.isHidden else { continue }
            guard let window = terminal.window else { continue }
            let windowPoint = window.convertPoint(fromScreen: mouseLocation)
            let viewPoint = terminal.convert(windowPoint, from: nil)
            guard terminal.bounds.contains(viewPoint) else { continue }
            guard terminal.allowMouseReporting else { continue }
            let mode = terminal.terminal?.mouseMode
            guard mode != nil, mode != .off else { continue }

            let cols = terminal.terminal!.cols
            let rows = terminal.terminal!.rows
            let cellW = terminal.bounds.width / CGFloat(cols)
            let cellH = terminal.bounds.height / CGFloat(rows)
            let col = max(0, min(Int(viewPoint.x / cellW), cols - 1))
            let row = max(0, min(Int(viewPoint.y / cellH), rows - 1))
            let pixelX = Int(viewPoint.x)
            let pixelY = Int(viewPoint.y)
            let button = event.deltaY > 0 ? 4 : 5
            let flags = terminal.terminal!.encodeButton(button: button, release: false, shift: false, meta: false, control: false)
            terminal.terminal!.sendEvent(buttonFlags: flags, x: col, y: row, pixelX: pixelX, pixelY: pixelY)
            return true
        }
        return false
    }
}

class TerminalContainerView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let activeTerminal = subviews.first(where: { !$0.isHidden && $0 is LocalProcessTerminalView })
        if let terminal = activeTerminal, terminal.frame.contains(point) {
            return terminal
        }
        return super.hitTest(point)
    }
}

@MainActor
class TerminalContainerManager {
    static let shared = TerminalContainerManager()
    private var container: TerminalContainerView?

    func getContainer() -> TerminalContainerView {
        if let existing = container, existing.window != nil {
            return existing
        }
        let newContainer = TerminalContainerView()
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
        TerminalEventMonitor.shared.install()
        let container = TerminalContainerManager.shared.getContainer()
        DispatchQueue.main.async {
            if let superview = container.superview {
                container.frame = superview.bounds
            }
        }
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        for tab in tabs {
            guard let termId = tab.terminalId else { continue }
            if let existing = TerminalManager.shared.get(for: termId) {
                if existing.superview == nil {
                    nsView.addSubview(existing)
                    existing.frame = nsView.bounds
                    existing.autoresizingMask = [.width, .height]
                }
            } else {
                createTerminal(cwd: tab.path, fontSize: fontSize, type: tab.type, terminalId: termId, in: nsView)
            }
        }

        if let activeTab = tabs.first(where: { $0.id == activeTabId }),
           let termId = activeTab.terminalId {
            TerminalManager.shared.show(id: termId)
        }
    }

    private func createTerminal(cwd: String, fontSize: Double, type: TabType, terminalId: String, in container: NSView) {
        let terminal = CodniaTerminalView(frame: container.bounds)
        TerminalManager.shared.set(terminal, for: terminalId)
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

        let (executable, args): (String, [String])
        switch type {
        case .opencode:
            executable = "/bin/zsh"
            args = ["-l", "-c", "opencode"]
        case .claude:
            executable = "/bin/zsh"
            args = ["-l", "-c", "claude"]
        case .codex:
            executable = "/bin/zsh"
            args = ["-l", "-c", "codex"]
        default:
            executable = "/bin/zsh"
            args = ["-l"]
        }

        terminal.startProcess(
            executable: executable,
            args: args,
            environment: envStrings,
            execName: nil,
            currentDirectory: cwd.isEmpty ? nil : cwd
        )

        container.addSubview(terminal)
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
