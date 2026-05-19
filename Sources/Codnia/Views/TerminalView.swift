import SwiftUI
import SwiftTerm
import Carbon

class CodniaTerminalView: LocalProcessTerminalView {
    var onDataReceived: ((Int) -> Void)?

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        onDataReceived?(slice.count)
    }

    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        if let url = URL(string: link) {
            BrowserService.handleTerminalURLClick(url)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu(title: "Terminal")
        let clearItem = NSMenuItem(title: "Clear", action: #selector(clearTerminal), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        return menu
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(clearTerminal) {
            return true
        }
        return super.validateUserInterfaceItem(item)
    }

    @objc func clearTerminal() {
        feed(text: "\u{001b}[2J\u{001b}[3J\u{001b}[H")
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
        terminal.frame = terminal.superview?.bounds ?? terminal.frame
        if let window = terminal.window ?? NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            _ = window.makeFirstResponder(terminal)
        }
    }

    func hideAll() {
        for terminal in terminals.values {
            terminal.isHidden = true
        }
    }

    func reset() {
        for (_, terminal) in terminals {
            terminal.isHidden = true
        }
    }

    func getAll() -> [String: CodniaTerminalView] {
        terminals
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
        terminal.send(txt: text)
    }

    func focus(id: String) {
        guard let terminal = terminals[id] else { return }
        DispatchQueue.main.async {
            if let window = NSApplication.shared.keyWindow {
                _ = window.makeFirstResponder(terminal)
            }
        }
    }

    func paste(id: String, text: String) {
        guard let terminal = terminals[id] else {
            return
        }
        terminal.send(txt: text)
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
    private static var installed = false

    func install() {
        guard !Self.installed else { return }
        Self.installed = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self else { return event }
            let result = self.handle(event)
            return result ? nil : event
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        let terminals = TerminalSessionManager.shared.getAllTerminals()
        let mouseLocation = NSEvent.mouseLocation
        for terminal in terminals {
            guard !terminal.isHidden else { continue }
            guard let window = terminal.window else { continue }
            let windowPoint = window.convertPoint(fromScreen: mouseLocation)
            let viewPoint = terminal.convert(windowPoint, from: nil)
            guard terminal.bounds.contains(viewPoint) else { continue }

            guard terminal.allowMouseReporting else { return false }
            let mode = terminal.terminal?.mouseMode
            guard mode != nil, mode != .off else { return false }

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

    private var isDraggingOver = false {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .string])
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isDraggingOver {
            NSColor(Color.accentBlue).withAlphaComponent(0.2).setFill()
            dirtyRect.fill()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidBecomeKey),
                name: NSWindow.didBecomeKeyNotification,
                object: window
            )
        }
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        if let activeTerminal = subviews.first(where: { !$0.isHidden && $0 is LocalProcessTerminalView }) as? CodniaTerminalView {
            DispatchQueue.main.async {
                _ = self.window?.makeFirstResponder(activeTerminal)
            }
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let activeTerminal = subviews.first(where: { !$0.isHidden && $0 is LocalProcessTerminalView })
        if let terminal = activeTerminal, terminal.frame.contains(point) {
            return terminal
        }
        return super.hitTest(point)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isDraggingOver = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDraggingOver = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDraggingOver = false
        let pasteboard = sender.draggingPasteboard

        var textToPaste: String?

        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let first = fileURLs.first {
            textToPaste = first.path
        } else if let strings = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String], let first = strings.first {
            textToPaste = first
        }

        guard let text = textToPaste, !text.isEmpty else {
            return false
        }

        for (id, terminal) in TerminalManager.shared.getAll() {
            if !terminal.isHidden {
                TerminalManager.shared.paste(id: id, text: text)
                break
            }
        }
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        isDraggingOver = false
    }
}

@MainActor
class TerminalContainerManager {
    static let shared = TerminalContainerManager()
    private var container: TerminalContainerView?

    func getContainer() -> TerminalContainerView {
        if let existing = container {
            return existing
        }
        let newContainer = TerminalContainerView()
        newContainer.autoresizingMask = [.width, .height]
        container = newContainer
        return newContainer
    }

    func clearContainer() {
        container = nil
    }
}

struct TerminalHostView: NSViewRepresentable {
    @Binding var tabs: [Tab]
    @Binding var activeTabId: String?
    let fontSize: Double

    func makeNSView(context: Context) -> NSView {
        let container = TerminalContainerManager.shared.getContainer()
        DispatchQueue.main.async {
            if let superview = container.superview {
                container.frame = superview.bounds
            }
        }
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let hasActiveTerminal = tabs.first(where: { $0.id == activeTabId })?.terminalId != nil

        for tab in tabs {
            guard let termId = tab.terminalId else { continue }
            if let existing = TerminalManager.shared.get(for: termId) {
                if existing.superview == nil {
                    nsView.addSubview(existing)
                }
                existing.frame = nsView.bounds
                existing.autoresizingMask = [.width, .height]
            } else {
                createTerminal(cwd: tab.path, fontSize: fontSize, type: tab.type, terminalId: termId, in: nsView)
            }
        }

        if hasActiveTerminal, let activeTab = tabs.first(where: { $0.id == activeTabId }),
           let termId = activeTab.terminalId {
            for (id, terminal) in TerminalManager.shared.getAll() {
                terminal.isHidden = (id != termId)
            }
            if let terminal = TerminalManager.shared.get(for: termId) {
                terminal.frame = nsView.bounds
                if let window = terminal.window ?? NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
                    _ = window.makeFirstResponder(terminal)
                }
            }
        } else {
            for (_, terminal) in TerminalManager.shared.getAll() {
                terminal.isHidden = true
            }
        }
    }

    private func createTerminal(cwd: String, fontSize: Double, type: TabType, terminalId: String, in container: NSView) {
        let terminal = CodniaTerminalView(frame: container.bounds)
        TerminalManager.shared.set(terminal, for: terminalId)
        TerminalSessionManager.shared.attachTerminal(terminal, to: terminalId)
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

import SwiftUI
import UniformTypeIdentifiers

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
        .onDrop(of: [.text, .fileURL], isTargeted: nil) { providers in
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        var path: String?
                        if let url = item as? URL {
                            path = url.path
                        } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            path = url.path
                        }
                        guard let text = path else { return }
                        DispatchQueue.main.async {
                            self.pasteToActiveTerminal(text: text)
                        }
                    }
                } else {
                    provider.loadObject(ofClass: NSString.self) { object, _ in
                        guard let text = object as? String else { return }
                        DispatchQueue.main.async {
                            self.pasteToActiveTerminal(text: text)
                        }
                    }
                }
            }
            return true
        }
    }

    private func pasteToActiveTerminal(text: String) {
        guard let termId = tabs.first(where: { $0.id == activeTabId })?.terminalId else { return }
        TerminalManager.shared.paste(id: termId, text: text)
    }
}
