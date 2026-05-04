import Foundation

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
}
