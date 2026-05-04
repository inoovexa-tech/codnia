import Foundation
import Combine

public final class TerminalService: ObservableObject {
    @Published public var instances: [TerminalInstance] = []
    private var processes: [String: Process] = [:]
    private var pipes: [String: (output: Pipe, input: Pipe)] = [:]

    public init() {}

    public func createTerminal(cwd: String? = nil, command: String? = nil) -> TerminalInstance {
        let id = UUID().uuidString
        let instance = TerminalInstance(id: id, name: command ?? "Terminal", cwd: cwd ?? NSHomeDirectory())
        instances.append(instance)

        let process = Process()
        let outputPipe = Pipe()
        let inputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l"]
        if let cwd = cwd { process.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        process.standardOutput = outputPipe
        process.standardInput = inputPipe
        process.standardError = outputPipe
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["PATH": buildUserPath()],
            uniquingKeysWith: { _, new in new }
        )

        processes[id] = process
        pipes[id] = (outputPipe, inputPipe)

        do {
            try process.run()
        } catch {
            print("Terminal start failed: \(error)")
        }

        return instance
    }

    public func write(id: String, data: String) {
        guard let inputPipe = pipes[id]?.input else { return }
        if let dataToSend = data.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(dataToSend)
        }
    }

    public func resize(id: String, rows: UInt16, cols: UInt16) {
        // POSIX resize — simplified, can be improved with ioctl
    }

    public func kill(id: String) {
        if let process = processes[id] {
            process.terminate()
            processes.removeValue(forKey: id)
            pipes.removeValue(forKey: id)
        }
        instances.removeAll { $0.id == id }
    }

    public func getOutputHandle(id: String) -> FileHandle? {
        return pipes[id]?.output.fileHandleForReading
    }

    private func buildUserPath() -> String {
        let home = NSHomeDirectory()
        let paths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "\(home)/.local/bin",
            "\(home)/.cargo/bin",
            "/usr/bin", "/bin", "/usr/sbin", "/sbin"
        ]
        return paths.joined(separator: ":")
    }
}

public struct TerminalInstance: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var cwd: String

    public static func == (lhs: TerminalInstance, rhs: TerminalInstance) -> Bool {
        lhs.id == rhs.id
    }
}
