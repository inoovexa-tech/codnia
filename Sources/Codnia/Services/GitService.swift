import Foundation

public struct GitStatusEntry: Identifiable, Equatable, Sendable {
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

@MainActor
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

    private func parseNumstatPerFile(_ data: Data?) -> [String: (added: Int, deleted: Int)] {
        guard let data = data,
              let output = String(data: data, encoding: .utf8) else { return [:] }
        var result: [String: (added: Int, deleted: Int)] = [:]
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        for line in lines {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            if parts.count >= 3 {
                let addedStr = String(parts[0])
                let deletedStr = String(parts[1])
                let filePath = String(parts[2])
                let added = addedStr != "-" ? (Int(addedStr) ?? 0) : 0
                let deleted = deletedStr != "-" ? (Int(deletedStr) ?? 0) : 0
                let existing = result[filePath] ?? (0, 0)
                result[filePath] = (existing.added + added, existing.deleted + deleted)
            }
        }
        return result
    }

    public func getFileChangesCounts(path: String) async -> [String: (added: Int, deleted: Int)] {
        let diffData = await runGit(args: ["diff", "--numstat"], in: path)
        let stagedData = await runGit(args: ["diff", "--cached", "--numstat"], in: path)
        let untrackedData = await runGit(args: ["ls-files", "--others", "--exclude-standard"], in: path)

        var result = parseNumstatPerFile(diffData)
        let stagedResult = parseNumstatPerFile(stagedData)
        for (filePath, counts) in stagedResult {
            let existing = result[filePath] ?? (0, 0)
            result[filePath] = (existing.added + counts.added, existing.deleted + counts.deleted)
        }

        if let data = untrackedData,
           let output = String(data: data, encoding: .utf8) {
            let files = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            for file in files {
                let existing = result[file] ?? (0, 0)
                result[file] = (existing.added + 1, existing.deleted)
            }
        }

        return result
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
        let diffData = await runGit(args: ["diff", "--numstat"], in: path)
        let stagedData = await runGit(args: ["diff", "--cached", "--numstat"], in: path)
        let untrackedData = await runGit(args: ["ls-files", "--others", "--exclude-standard"], in: path)

        var added = 0
        var deleted = 0

        parseNumstat(diffData, into: &added, deleted: &deleted)
        parseNumstat(stagedData, into: &added, deleted: &deleted)

        if let data = untrackedData,
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
            var filePart = line.dropFirst(3)

            if filePart.hasPrefix("\"") && filePart.hasSuffix("\"") {
                filePart = filePart.dropFirst().dropLast()
            }

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
        let result = await runGitWithResult(args: ["reset", "HEAD", "--", filePath], in: path)
        return result.success
    }

    // MARK: - Discard

    public func discardFileChanges(path: String, filePath: String) async -> Bool {
        let fullPath = (path as NSString).appendingPathComponent(filePath)
        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory)

        if !fileExists {
            return true
        }

        let checkoutResult = await runGitWithResult(args: ["checkout", "--", filePath], in: path)
        if checkoutResult.success {
            return true
        }

        do {
            if isDirectory.boolValue {
                try FileManager.default.removeItem(atPath: fullPath)
            } else {
                try FileManager.default.removeItem(atPath: fullPath)
            }
            return true
        } catch {
            return false
        }
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

    // MARK: - Worktrees

    public struct WorktreeInfo: Identifiable {
        public let id: String
        public let path: String
        public let branch: String
        public let isMain: Bool

        public init(path: String, branch: String, isMain: Bool) {
            self.id = path
            self.path = path
            self.branch = branch
            self.isMain = isMain
        }
    }

    public func listWorktrees(path projectPath: String) async -> [WorktreeInfo] {
        guard let output = await runGitOutput(args: ["worktree", "list", "--porcelain"], in: projectPath) else {
            return []
        }

        var worktrees: [WorktreeInfo] = []
        let lines = output.components(separatedBy: .newlines)

        var currentPath = ""
        var currentBranch = ""
        var isMain = false

        for line in lines {
            if line.hasPrefix("worktree ") {
                let pathPart = line.dropFirst("worktree ".count)
                if pathPart == projectPath {
                    isMain = true
                } else {
                    isMain = false
                }
                currentPath = String(pathPart)
            } else if line.hasPrefix("branch ") {
                currentBranch = String(line.dropFirst("branch ".count))
            } else if line.isEmpty && !currentPath.isEmpty {
                if !currentBranch.isEmpty {
                    worktrees.append(WorktreeInfo(path: currentPath, branch: currentBranch, isMain: isMain))
                }
                currentPath = ""
                currentBranch = ""
                isMain = false
            }
        }

        if !currentPath.isEmpty && !currentBranch.isEmpty {
            worktrees.append(WorktreeInfo(path: currentPath, branch: currentBranch, isMain: isMain))
        }

        return worktrees
    }

    public func addWorktree(projectPath: String, branch: String, worktreePath: String, createBranch: Bool) async -> Bool {
        var args = ["worktree", "add"]

        if createBranch {
            args.append("-b")
            args.append(branch)
            args.append(worktreePath)
        } else {
            args.append(worktreePath)
            args.append(branch)
        }

        let result = await runGitWithResult(args: args, in: projectPath)
        return result.success
    }

    public func removeWorktree(projectPath: String, worktreePath: String, worktreeBranch: String, deleteBranch: Bool) async -> Bool {
        let result = await runGitWithResult(args: ["worktree", "remove", worktreePath], in: projectPath)

        let isRemovedFromGit: Bool
        if result.success {
            isRemovedFromGit = true
        } else {
            let dirExists = FileManager.default.fileExists(atPath: worktreePath)
            let notTracked = result.output.contains("is not a working tree")
            isRemovedFromGit = !dirExists || notTracked
        }

        guard isRemovedFromGit else { return false }

        if deleteBranch {
            _ = await runGitWithResult(args: ["branch", "-D", worktreeBranch], in: projectPath)
        }
        return true
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
        if !result.success {
            let conflictIndicators = ["CONFLICT", "merge failed", "conflict"]
            if conflictIndicators.contains(where: { result.output.localizedCaseInsensitiveContains($0) }) {
                return false
            }
        }
        return result.success
    }

    // MARK: - Log

    public struct CommitInfo: Identifiable, Sendable {
        public let id: String
        public let hash: String
        public let shortHash: String
        public let message: String
        public let author: String
        public let date: String

        public init(hash: String, message: String, author: String, date: String) {
            self.id = hash
            self.hash = hash
            self.shortHash = String(hash.prefix(7))
            self.message = message
            self.author = author
            self.date = date
        }
    }

    public func getLog(path: String, count: Int = 20) async -> [CommitInfo] {
        let format = "%H|%s|%an|%ad"
        guard let output = await runGitOutput(args: ["log", "--format=\(format)", "--date=short", "-\(count)"], in: path) else {
            return []
        }
        return output.components(separatedBy: .newlines).filter { !$0.isEmpty }.compactMap { line in
            let parts = line.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count >= 4 else { return nil }
            return CommitInfo(
                hash: String(parts[0]),
                message: String(parts[1]),
                author: String(parts[2]),
                date: String(parts[3])
            )
        }
    }
}

private extension String {
    func trimmed() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
