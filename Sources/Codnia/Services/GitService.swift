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
            var added = 0
            var deleted = 0

            let diffTask = Process()
            diffTask.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            diffTask.arguments = ["diff", "--numstat"]
            diffTask.currentDirectoryURL = URL(fileURLWithPath: path)
            diffTask.standardOutput = Pipe()
            diffTask.standardError = Pipe()

            do {
                try diffTask.run()
                diffTask.waitUntilExit()
                if let data = (diffTask.standardOutput as? Pipe)?.fileHandleForReading.readDataToEndOfFile(),
                   let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    for line in lines {
                        let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
                        if parts.count >= 2 {
                            let addedStr = String(parts[0])
                            let deletedStr = String(parts[1])
                            if addedStr != "-" { added += Int(addedStr) ?? 0 }
                            if deletedStr != "-" { deleted += Int(deletedStr) ?? 0 }
                        }
                    }
                }
            } catch {}

            let stagedTask = Process()
            stagedTask.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            stagedTask.arguments = ["diff", "--cached", "--numstat"]
            stagedTask.currentDirectoryURL = URL(fileURLWithPath: path)
            stagedTask.standardOutput = Pipe()
            stagedTask.standardError = Pipe()

            do {
                try stagedTask.run()
                stagedTask.waitUntilExit()
                if let data = (stagedTask.standardOutput as? Pipe)?.fileHandleForReading.readDataToEndOfFile(),
                   let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    for line in lines {
                        let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
                        if parts.count >= 2 {
                            let addedStr = String(parts[0])
                            let deletedStr = String(parts[1])
                            if addedStr != "-" { added += Int(addedStr) ?? 0 }
                            if deletedStr != "-" { deleted += Int(deletedStr) ?? 0 }
                        }
                    }
                }
            } catch {}

            let untrackedTask = Process()
            untrackedTask.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            untrackedTask.arguments = ["ls-files", "--others", "--exclude-standard"]
            untrackedTask.currentDirectoryURL = URL(fileURLWithPath: path)
            untrackedTask.standardOutput = Pipe()

            do {
                try untrackedTask.run()
                untrackedTask.waitUntilExit()
                if let data = (untrackedTask.standardOutput as? Pipe)?.fileHandleForReading.readDataToEndOfFile(),
                   let output = String(data: data, encoding: .utf8) {
                    let untrackedCount = output.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
                    added += untrackedCount
                }
            } catch {}

            completion(added, deleted)
        }
    }
}
