import Foundation
import Combine

public final class TerminalService: ObservableObject {
    @Published public var instances: [TerminalInstance] = []

    public init() {}

    public func createTerminal(cwd: String? = nil) -> TerminalInstance {
        let id = UUID().uuidString
        let instance = TerminalInstance(id: id, name: "Terminal", cwd: cwd ?? NSHomeDirectory())
        instances.append(instance)
        return instance
    }

    public func kill(id: String) {
        instances.removeAll { $0.id == id }
    }
}

public struct TerminalInstance: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var cwd: String

    public init(id: String = UUID().uuidString, name: String, cwd: String) {
        self.id = id
        self.name = name
        self.cwd = cwd
    }

    public static func == (lhs: TerminalInstance, rhs: TerminalInstance) -> Bool {
        lhs.id == rhs.id
    }
}