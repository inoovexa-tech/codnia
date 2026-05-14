import Foundation
import Combine

public final class TerminalService: ObservableObject {
    @Published public var instances: [TerminalInstance] = []

    public init() {}

    public func createTerminal(cwd: String? = nil, worktreeId: String? = nil, sessionId: String? = nil) -> TerminalInstance {
        let id = UUID().uuidString
        let instance = TerminalInstance(id: id, name: "Terminal", cwd: cwd ?? NSHomeDirectory(), worktreeId: worktreeId, sessionId: sessionId)
        instances.append(instance)
        return instance
    }

    public func setProcessRunning(id: String, running: Bool) {
        guard let idx = instances.firstIndex(where: { $0.id == id }) else { return }
        instances[idx].isProcessRunning = running
    }

    public func kill(id: String) {
        instances.removeAll { $0.id == id }
    }
}

public struct TerminalInstance: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var cwd: String
    public var worktreeId: String?
    public var isProcessRunning: Bool = true
    public var sessionId: String?

    public init(id: String = UUID().uuidString, name: String, cwd: String, worktreeId: String? = nil, sessionId: String? = nil) {
        self.id = id
        self.name = name
        self.cwd = cwd
        self.worktreeId = worktreeId
        self.sessionId = sessionId
    }

    public static func == (lhs: TerminalInstance, rhs: TerminalInstance) -> Bool {
        lhs.id == rhs.id
    }
}