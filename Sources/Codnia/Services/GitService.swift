import Foundation

public struct GitStatusEntry: Identifiable, Equatable {
    public let id: String
    public let filePath: String
    public let status: String
    public let isStaged: Bool

    public init(filePath: String, status: String, isStaged: Bool) {
        self.id = filePath
        self.filePath = filePath
        self.status = status
        self.isStaged = isStaged
    }
}

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

    private func runGitOutput(args: [String], in path: String) async -> String? {
        guard let data = await runGit(args: args, in: path),
              let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else { return nil }
        return output
    }

    private func runGitWithResult(args: [String], in path: String) async -> (success: Bool, output: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = args
        task.currentDirectoryURL = URL(fileURLWithPath: path)

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        return await withCheckedContinuation { continuation in
            task.terminationHandler = { process in
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outData, encoding: .utf8) ?? ""
                let error = String(data: errData, encoding: .utf8) ?? ""
                let combined = output + (error.isEmpty ? "" : "\n" + error)
                continuation.resume(returning: (process.terminationStatus == 0, combined.trimmed()))
            }

            do {
                try task.run()
                outPipe.fileHandleForWriting.closeFile()
                errPipe.fileHandleForWriting.closeFile()
            } catch {
                continuation.resume(returning: (false, error.localizedDescription))
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

    // MARK: - Public API (existing)

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

    // MARK: - Status

    public func getStatus(path: String) async -> [GitStatusEntry] {
        guard let output = await runGitOutput(args: ["status", "--porcelain"], in: path) else {
            return []
        }
        var entries: [GitStatusEntry] = []
        for line in output.components(separatedBy: .newlines) where !line.isEmpty {
            let statusPart = line.prefix(2)
            let filePart = line.dropFirst(3)
            let filePath = String(filePart)

            let stagedStatus = statusPart.prefix(1)
            let workingStatus = statusPart.suffix(1)

            if stagedStatus != " " {
                entries.append(GitStatusEntry(filePath: filePath, status: String(stagedStatus), isStaged: true))
            }
            if workingStatus != " " {
                entries.append(GitStatusEntry(filePath: filePath, status: String(workingStatus), isStaged: false))
            }
        }
        return entries
    }

    // MARK: - Diff

    public func getDiff(path: String, filePath: String? = nil, staged: Bool = false) async -> String? {
        var args = ["diff", "--color=never"]
        if staged { args.append("--cached") }
        if let filePath = filePath { args.append(filePath) }
        let output = await runGitOutput(args: args, in: path)
        return output
    }

    public func getOriginalFileContent(path: String, filePath: String, staged: Bool = false) async -> String? {
        if staged {
            // For staged changes, get the version from HEAD (before staging)
            return await runGitOutput(args: ["show", "HEAD:\(filePath)"], in: path)
        } else {
            // For unstaged changes, get the version from HEAD
            return await runGitOutput(args: ["show", "HEAD:\(filePath)"], in: path)
        }
    }

    public func getModifiedFileContent(path: String, filePath: String, staged: Bool = false) async -> String? {
        if staged {
            // For staged changes, the "modified" version is what's in the index
            return await runGitOutput(args: ["show", ":\(filePath)"], in: path)
        } else {
            // For unstaged changes, read from working tree
            let fullPath = (path as NSString).appendingPathComponent(filePath)
            guard let data = FileManager.default.contents(atPath: fullPath),
                  let content = String(data: data, encoding: .utf8) else {
                return nil
            }
            return content
        }
    }

    public func getFileContentAtHEAD(path: String, filePath: String) async -> String? {
        let output = await runGitOutput(args: ["show", "HEAD:\(filePath)"], in: path)
        return output
    }

    public func getWorkingFileContent(path: String, filePath: String) async -> String? {
        let fullPath = (path as NSString).appendingPathComponent(filePath)
        guard let data = FileManager.default.contents(atPath: fullPath),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        return content
    }

    // MARK: - Stage / Unstage

    public func stageFile(path: String, filePath: String) async -> Bool {
        let result = await runGitWithResult(args: ["add", filePath], in: path)
        return result.success
    }

    public func stageAll(path: String) async -> Bool {
        let result = await runGitWithResult(args: ["add", "-A"], in: path)
        return result.success
    }

    public func unstageFile(path: String, filePath: String) async -> Bool {
        let result = await runGitWithResult(args: ["restore", "--staged", filePath], in: path)
        return result.success
    }

    // MARK: - Discard

    public func discardFileChanges(path: String, filePath: String) async -> Bool {
        let result = await runGitWithResult(args: ["restore", filePath], in: path)
        return result.success
    }

    // MARK: - Commit

    public func commit(path: String, message: String) async -> Bool {
        let result = await runGitWithResult(args: ["commit", "-m", message], in: path)
        return result.success
    }

    // MARK: - Branches

    public func getBranches(path: String) async -> [String] {
        guard let output = await runGitOutput(args: ["branch", "--list"], in: path) else {
            return []
        }
        return output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "* ", with: "") }
            .filter { !$0.isEmpty }
    }

    public func createBranch(path: String, name: String) async -> Bool {
        let result = await runGitWithResult(args: ["branch", name], in: path)
        return result.success
    }

    public func checkoutBranch(path: String, name: String) async -> Bool {
        let result = await runGitWithResult(args: ["switch", name], in: path)
        return result.success
    }

    // MARK: - Remote operations

    public func pull(path: String) async -> Bool {
        let result = await runGitWithResult(args: ["pull"], in: path)
        return result.success
    }

    public func push(path: String) async -> Bool {
        let result = await runGitWithResult(args: ["push"], in: path)
        return result.success
    }

    public func fetch(path: String) async -> Bool {
        let result = await runGitWithResult(args: ["fetch", "--all"], in: path)
        return result.success
    }

    public func merge(path: String, branch: String) async -> Bool {
        let result = await runGitWithResult(args: ["merge", branch], in: path)
        return result.success
    }

    // MARK: - Log

    public func getLog(path: String, count: Int = 10) async -> [String] {
        guard let output = await runGitOutput(args: ["log", "--oneline", "-\(count)"], in: path) else {
            return []
        }
        return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }
}

private extension String {
    func trimmed() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
