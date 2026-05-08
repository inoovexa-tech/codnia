import Foundation

public final class GitService {
    public static let shared = GitService()
    private init() {}

    // MARK: - Internal helpers

    private func runGit(args: [String], in path: String) async -> Data? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = args
        task.currentDirectoryURL = URL(fileURLWithPath: path)

        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = FileHandle.nullDevice

        return await withCheckedContinuation { continuation in
            task.terminationHandler = { _ in
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: data.isEmpty ? nil : data)
            }

            do {
                try task.run()
                outPipe.fileHandleForWriting.closeFile()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    private func parseNumstat(_ data: Data?, into added: inout Int, deleted: inout Int) {
        guard let data = data,
              let output = String(data: data, encoding: .utf8) else { return }
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

    // MARK: - Public API

    public func getBranch(path: String) async -> String {
        guard let data = await runGit(args: ["rev-parse", "--abbrev-ref", "HEAD"], in: path),
              let branch = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !branch.isEmpty else {
            return ""
        }
        return branch
    }

    public func getChangesCount(path: String) async -> (added: Int, deleted: Int) {
        async let diffData = runGit(args: ["diff", "--numstat"], in: path)
        async let stagedData = runGit(args: ["diff", "--cached", "--numstat"], in: path)
        async let untrackedData = runGit(args: ["ls-files", "--others", "--exclude-standard"], in: path)

        var added = 0
        var deleted = 0

        parseNumstat(await diffData, into: &added, deleted: &deleted)
        parseNumstat(await stagedData, into: &added, deleted: &deleted)

        if let data = await untrackedData,
           let output = String(data: data, encoding: .utf8) {
            added += output.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
        }

        return (added: added, deleted: deleted)
    }
}
