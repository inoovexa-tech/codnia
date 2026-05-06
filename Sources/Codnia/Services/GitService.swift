import Foundation

@MainActor
public final class GitService {
    public static let shared = GitService()
    private init() {}

    public func getBranch(path: String, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            task.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
            task.currentDirectoryURL = URL(fileURLWithPath: path)
            task.standardOutput = Pipe()
            task.standardError = Pipe()

            do {
                try task.run()
                task.waitUntilExit()
                if let data = (task.standardOutput as? Pipe)?.fileHandleForReading.readDataToEndOfFile(),
                   let branch = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !branch.isEmpty {
                    completion(branch)
                } else {
                    completion("")
                }
            } catch {
                completion("")
            }
        }
    }

    public func getChangesCount(path: String, completion: @escaping (Int, Int) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            task.arguments = ["status", "--porcelain"]
            task.currentDirectoryURL = URL(fileURLWithPath: path)
            task.standardOutput = Pipe()
            task.standardError = Pipe()

            do {
                try task.run()
                task.waitUntilExit()
                if let data = (task.standardOutput as? Pipe)?.fileHandleForReading.readDataToEndOfFile(),
                   let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty {
                    let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    let added = lines.filter { $0.hasPrefix("A") || $0.hasPrefix("M") || $0.hasPrefix("?") }.count
                    let deleted = lines.filter { $0.hasPrefix("D") }.count
                    completion(added, deleted)
                } else {
                    completion(0, 0)
                }
            } catch {
                completion(0, 0)
            }
        }
    }
}
