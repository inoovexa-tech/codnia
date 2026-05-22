import Foundation
import AppKit
import Combine
import SwiftTerm

@MainActor
final class TerminalSessionManager: ObservableObject {
    static let shared = TerminalSessionManager()

    @Published private(set) var sessions: [String: TerminalSession] = [:]
    @Published private(set) var viewToSessionMap: [UUID: String] = [:]

    private var bytesSinceLastPoll: [String: Int] = [:]
    private var lastActiveTimes: [String: Date] = [:]

    private init() {}

    func getSession(for viewId: UUID) -> TerminalSession? {
        guard let sessionId = viewToSessionMap[viewId] else { return nil }
        return sessions[sessionId]
    }

    func getSessionByTerminalId(_ terminalId: String) -> TerminalSession? {
        sessions[terminalId]
    }

    func getSession(by id: String) -> TerminalSession? {
        sessions[id]
    }

    func createSession(cwd: String,
                       environment: [String: String],
                       executable: String = "/bin/zsh",
                       arguments: [String] = ["-l"],
                       tabType: TabType = .terminal) -> TerminalSession {
        let id = UUID().uuidString
        let session = TerminalSession(
            id: id,
            cwd: cwd,
            environment: environment,
            executable: executable,
            arguments: arguments,
            tabType: tabType
        )
        sessions[id] = session
        return session
    }

    func registerView(_ viewId: UUID, to sessionId: String) {
        viewToSessionMap[viewId] = sessionId
        sessions[sessionId]?.addView(viewId)
    }

    func unregisterView(_ viewId: UUID) {
        guard let sessionId = viewToSessionMap[viewId] else { return }
        sessions[sessionId]?.removeView(viewId)
        viewToSessionMap.removeValue(forKey: viewId)
        if let session = sessions[sessionId], session.viewIds.isEmpty {
            session.terminal?.terminate()
            sessions.removeValue(forKey: sessionId)
        }
    }

    func restoreView(_ viewId: UUID, to sessionId: String) {
        viewToSessionMap[viewId] = sessionId
        sessions[sessionId]?.addView(viewId)
    }

    func destroySession(id: String) {
        sessions[id]?.terminal?.terminate()
        sessions.removeValue(forKey: id)
    }

    func getAll() -> [String: TerminalSession] {
        sessions
    }

    func getAllTerminals() -> [CodniaTerminalView] {
        sessions.values.compactMap { $0.terminal }
    }

    func terminateProcess(for sessionId: String) {
        sessions[sessionId]?.terminal?.terminate()
    }

    func isProcessRunning(for sessionId: String) -> Bool {
        sessions[sessionId]?.isProcessRunning ?? false
    }

    func sendText(to sessionId: String, text: String) {
        sessions[sessionId]?.sendText(text)
    }

    func focus(sessionId: String) {
        sessions[sessionId]?.focus()
    }

    func paste(sessionId: String, text: String) {
        guard let session = sessions[sessionId], let terminal = session.terminal else { return }
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        terminal.selectAll(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let window = NSApplication.shared.keyWindow {
                _ = window.makeFirstResponder(terminal)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let source = CGEventSource(stateID: .combinedSessionState)
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
                keyDown?.flags = .maskCommand
                keyDown?.post(tap: .cgSessionEventTap)
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
                keyUp?.flags = .maskCommand
                keyUp?.post(tap: .cgSessionEventTap)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let old = oldContents {
                        pasteboard.clearContents()
                        pasteboard.setString(old, forType: .string)
                    }
                }
            }
        }
    }

    func recordBytes(for sessionId: String, bytes: Int) {
        if bytes > 0 {
            lastActiveTimes[sessionId] = Date()
        }
        bytesSinceLastPoll[sessionId] = (bytesSinceLastPoll[sessionId] ?? 0) + bytes
    }

    func isActivelyProcessing(for sessionId: String) -> Bool {
        let bytes = bytesSinceLastPoll[sessionId] ?? 0
        bytesSinceLastPoll[sessionId] = nil

        if bytes >= 150 {
            lastActiveTimes[sessionId] = Date()
            return true
        }

        if let lastActive = lastActiveTimes[sessionId], Date().timeIntervalSince(lastActive) < 1.5 {
            return true
        }

        lastActiveTimes.removeValue(forKey: sessionId)
        return false
    }

    func attachTerminal(_ terminal: CodniaTerminalView, to sessionId: String) {
        guard let session = sessions[sessionId] else { return }
        session.terminal = terminal
        terminal.onDataReceived = { [weak self] byteCount in
            DispatchQueue.main.async {
                self?.recordBytes(for: sessionId, bytes: byteCount)
            }
        }
    }

    func clearAll() {
        for (_, session) in sessions {
            session.terminal?.terminate()
        }
        sessions.removeAll()
        viewToSessionMap.removeAll()
    }
}