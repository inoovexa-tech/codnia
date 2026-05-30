import SwiftUI
import SwiftTerm
import AppKit

struct TerminalSingleView: View {
    let viewId: UUID
    let fontSize: Double

    var body: some View {
        TerminalSessionView(viewId: viewId, fontSize: fontSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bgPrimary)
    }
}

class SessionViewportView: NSView {
    var viewId: UUID?
    var sessionId: String?

    private var _terminal: CodniaTerminalView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .string])
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
    }

    override func layout() {
        super.layout()
        guard bounds.width > 0 && bounds.height > 0 else { return }
        reclaimTerminalIfNeeded()
        subviews.forEach {
            $0.frame = bounds
            if let term = $0 as? CodniaTerminalView {
                term.displayIfNeeded()
            }
        }
    }

    func reclaimTerminalIfNeeded() {
        guard let sessionId = sessionId,
              let session = TerminalSessionManager.shared.getSession(by: sessionId),
              let terminal = session.terminal else { return }
        guard self.window != nil else { return }
        if terminal.superview != self {
            session.saveViewportState()
            terminal.removeFromSuperview()
            addSubview(terminal)
            terminal.autoresizingMask = [.width, .height]
            terminal.isHidden = false
            session.restoreViewportState()
        }
        terminal.frame = bounds
        terminal.needsDisplay = true
        terminal.displayIfNeeded()
    }

    func createAndAttachTerminal(to session: TerminalSession, fontSize: Double) {
        let terminal = CodniaTerminalView(frame: bounds)
        _terminal = terminal
        terminal.autoresizingMask = [.width, .height]
        terminal.nativeBackgroundColor = NSColor(Color.bgPrimary)
        terminal.nativeForegroundColor = NSColor(Color.textPrimary)
        terminal.font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        terminal.isHidden = false

        TerminalManager.shared.set(terminal, for: session.id)
        TerminalSessionManager.shared.attachTerminal(terminal, to: session.id)

        terminal.startProcess(
            executable: session.executable,
            args: session.arguments,
            environment: session.environment.map { "\($0.key)=\($0.value)" },
            execName: nil,
            currentDirectory: session.cwd.isEmpty ? nil : session.cwd
        )

        addSubview(terminal)
    }

    func createNewSession(viewId: UUID, fontSize: Double) {
        var env = ProcessInfo.processInfo.environment
        if env["HOME"] == nil { env["HOME"] = NSHomeDirectory() }
        if env["SHELL"] == nil { env["SHELL"] = "/bin/zsh" }
        if env["TERM"] == nil { env["TERM"] = "xterm-256color" }
        if env["LANG"] == nil { env["LANG"] = "en_US.UTF-8" }

        let session = TerminalSessionManager.shared.createSession(
            cwd: NSHomeDirectory(),
            environment: env,
            executable: "/bin/zsh",
            arguments: ["-l"]
        )

        TerminalSessionManager.shared.registerView(viewId, to: session.id)
        sessionId = session.id
        createAndAttachTerminal(to: session, fontSize: fontSize)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
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

        if let sessionId = self.sessionId {
            TerminalManager.shared.paste(id: sessionId, text: text)
        }
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
    }
}

struct TerminalSessionView: NSViewRepresentable {
    let viewId: UUID
    let fontSize: Double

    func makeNSView(context: Context) -> NSView {
        let container = SessionViewportView()
        container.viewId = viewId

        if let session = TerminalSessionManager.shared.getSession(for: viewId) {
            container.sessionId = session.id
            if session.terminal == nil {
                container.createAndAttachTerminal(to: session, fontSize: fontSize)
            }
        } else {
            container.createNewSession(viewId: viewId, fontSize: fontSize)
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let container = nsView as? SessionViewportView else { return }
        container.viewId = viewId

        // Case 1: viewId is registered to a session
        if let session = TerminalSessionManager.shared.getSession(for: viewId) {
            container.sessionId = session.id
            if session.terminal != nil {
                container.reclaimTerminalIfNeeded()
                return
            }
        }

        // Case 2: container has sessionId but viewId isn't registered (orphaned pane)
        if let sessionId = container.sessionId,
           let session = TerminalSessionManager.shared.getSession(by: sessionId),
           session.terminal != nil {
            TerminalSessionManager.shared.registerView(viewId, to: sessionId)
            container.reclaimTerminalIfNeeded()
            return
        }

        // Case 3: container has sessionId but no terminal (session empty)
        if let sessionId = container.sessionId,
           let session = TerminalSessionManager.shared.getSession(by: sessionId) {
            TerminalSessionManager.shared.registerView(viewId, to: sessionId)
            container.createAndAttachTerminal(to: session, fontSize: fontSize)
            return
        }

        container.createNewSession(viewId: viewId, fontSize: fontSize)
    }
}

@available(macOS 13.0, *)
struct TerminalSingleContainerView: NSViewRepresentable {
    let viewId: UUID
    let fontSize: Double

    func makeNSView(context: Context) -> NSView {
        let container = SessionViewportView()
        container.viewId = viewId
        container.createNewSession(viewId: viewId, fontSize: fontSize)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let container = nsView as? SessionViewportView else { return }
        container.viewId = viewId
        if let sessionId = container.sessionId,
           let session = TerminalSessionManager.shared.getSession(by: sessionId),
           session.terminal != nil {
            container.reclaimTerminalIfNeeded()
        }
    }
}