import SwiftUI
import Combine

@MainActor
public final class GitViewModel: ObservableObject {
    @Published public var statusEntries: [GitStatusEntry] = []
    @Published public var stagedEntries: [GitStatusEntry] = []
    @Published public var unstagedEntries: [GitStatusEntry] = []
    @Published public var currentBranch: String = ""
    @Published public var branches: [String] = []
    @Published public var commitMessage: String = ""
    @Published public var isLoading: Bool = false
    @Published public var isRefreshing: Bool = false
    @Published public var isAutoRefreshing: Bool = false
    @Published public var isCommitting: Bool = false
    @Published public var actionMessage: String? = nil {
        didSet {
            if actionMessage != nil { scheduleAutoDismiss() }
        }
    }
    @Published public var actionError: String? = nil {
        didSet {
            if actionError != nil { scheduleAutoDismiss() }
        }
    }
    @Published public var commitHistory: [GitService.CommitInfo] = []
    @Published public var showCommitHistory: Bool = false
    @Published public var fileChangesCounts: [String: (added: Int, deleted: Int)] = [:]
    @Published public var hasRemote: Bool = false
    @Published public var isAmending: Bool = false

    private let git = GitService.shared
    private weak var workspace: WorkspaceService?
    private weak var editorVM: EditorViewModel?
    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?
    private var autoDismissTask: Task<Void, Never>?

    public init(workspace: WorkspaceService, editorVM: EditorViewModel) {
        self.workspace = workspace
        self.editorVM = editorVM

        observeWorktreeChanges()
    }

    deinit {
        refreshTask?.cancel()
        autoDismissTask?.cancel()
    }

    private func observeWorktreeChanges() {
        guard let workspace = workspace else { return }

        if let project = workspace.activeProject, let worktree = project.activeWorktree {
            refreshAll(for: worktree.path)
        }

        workspace.$activeProject
            .receive(on: RunLoop.main)
            .sink { [weak self] project in
                guard let self = self, let project = project, let worktree = project.activeWorktree else { return }
                self.refreshAll(for: worktree.path)
            }
            .store(in: &cancellables)

        workspace.objectWillChange
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.refreshIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func refreshIfNeeded() {
        guard !isRefreshing, !isLoading, !isCommitting else { return }
        isAutoRefreshing = true
        refreshAll()
    }

    public func refreshAll(for path: String? = nil) {
        refreshTask?.cancel()
        let worktreePath = path ?? workspace?.activeProject?.activeWorktree?.path
        guard let worktreePath = worktreePath else { return }

        refreshTask = Task { [weak self] in
            guard let self = self else { return }
            self.isRefreshing = true
            self.isLoading = true

            async let status = self.git.getStatus(path: worktreePath)
            async let branch = self.git.getBranch(path: worktreePath)
            async let branches = self.git.getBranches(path: worktreePath)
            async let history = self.git.getLog(path: worktreePath, count: 20)
            async let counts = self.git.getFileChangesCounts(path: worktreePath)
            async let remote = self.git.hasRemote(path: worktreePath)

            let (statusResult, branchResult, branchesResult, historyResult, countsResult, remoteResult) = await (status, branch, branches, history, counts, remote)

            guard !Task.isCancelled else { return }

            self.statusEntries = statusResult
            self.stagedEntries = statusResult.filter { $0.isStaged }
            self.unstagedEntries = statusResult.filter { !$0.isStaged }
            self.currentBranch = branchResult
            self.branches = branchesResult
            self.commitHistory = historyResult
            self.fileChangesCounts = countsResult
            self.hasRemote = remoteResult
            self.isLoading = false
            self.isRefreshing = false
            self.isAutoRefreshing = false
        }
    }

    private var worktreePath: String? {
        workspace?.activeProject?.activeWorktree?.path
    }

    public func stageFile(_ filePath: String) {
        guard let path = worktreePath else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.stageFile(path: path, filePath: filePath)
            if success {
                self.refreshAll()
            } else {
                self.actionError = "Failed to stage file"
            }
        }
    }

    public func stageAll() {
        guard let path = worktreePath else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.stageAll(path: path)
            if success {
                self.refreshAll()
            } else {
                self.actionError = "Failed to stage all files"
            }
        }
    }

    public func unstageFile(_ filePath: String) {
        guard let path = worktreePath else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.unstageFile(path: path, filePath: filePath)
            if success {
                self.refreshAll()
            } else {
                self.actionError = "Failed to unstage file"
            }
        }
    }

    public func unstageAll() {
        guard let path = worktreePath else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.unstageAll(path: path)
            if success {
                self.refreshAll()
            } else {
                self.actionError = "Failed to unstage all files"
            }
        }
    }

    public func discardFile(_ filePath: String) {
        guard let path = worktreePath else { return }
        Task { [weak self] in
            guard let self = self else { return }
            if self.stagedEntries.contains(where: { $0.filePath == filePath }) {
                _ = await self.git.unstageFile(path: path, filePath: filePath)
            }
            let success = await self.git.discardFileChanges(path: path, filePath: filePath)
            if success {
                self.actionMessage = "Discarded changes in \(filePath)"
                self.refreshAll()
            } else {
                self.actionError = "Failed to discard changes"
            }
        }
    }

    public func openDiff(for entry: GitStatusEntry) {
        guard let path = worktreePath,
              let editorVM = editorVM else { return }

        Task { [weak self] in
            guard let self = self else { return }

            async let originalContent = self.git.getOriginalFileContent(
                path: path,
                filePath: entry.filePath,
                staged: entry.isStaged
            )
            async let modifiedContent = self.git.getModifiedFileContent(
                path: path,
                filePath: entry.filePath,
                staged: entry.isStaged
            )

            let (original, modified) = await (originalContent, modifiedContent)

            let originalLines = original?.components(separatedBy: .newlines) ?? []
            let modifiedLines = modified?.components(separatedBy: .newlines) ?? []

            let diffLines = DiffProcessor.computeDiff(original: originalLines, modified: modifiedLines)

            let tabName = entry.isStaged
                ? "\(entry.filePath) (staged)"
                : entry.filePath

            let tab = Tab(
                path: entry.filePath,
                name: tabName,
                language: "Diff",
                type: .diff
            )

            editorVM.tabs.append(tab)
            editorVM.activeTabId = tab.id
            editorVM.diffData[tab.id] = diffLines
            editorVM.currentLanguage = "Diff"
            editorVM.objectWillChange.send()
        }
    }

    public func commit() {
        guard let path = worktreePath else { return }
        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            actionError = "Commit message cannot be empty"
            return
        }
        guard !stagedEntries.isEmpty else {
            actionError = "No files staged for commit"
            return
        }

        isCommitting = true
        actionError = nil

        Task { [weak self] in
            guard let self = self else {
                await MainActor.run { [weak self] in self?.isCommitting = false }
                return
            }
            defer { self.isCommitting = false }

            let success = await self.git.commit(path: path, message: message, amend: self.isAmending)

            if success {
                self.commitMessage = ""
                self.isAmending = false
                self.actionMessage = "Committed successfully"
                self.refreshAll()
            } else {
                self.actionError = "Commit failed"
            }
        }
    }

    public func createBranch(name: String) {
        guard let path = worktreePath else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.createBranch(path: path, name: name)
            if success {
                self.actionMessage = "Created branch '\(name)'"
                self.refreshAll()
            } else {
                self.actionError = "Failed to create branch '\(name)'"
            }
        }
    }

    public func checkoutBranch(name: String) {
        guard let path = worktreePath else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.checkoutBranch(path: path, name: name)
            if success {
                self.actionMessage = "Switched to branch '\(name)'"
                self.refreshAll()
            } else {
                self.actionError = "Failed to switch to branch '\(name)'"
            }
        }
    }

    public func pull() {
        guard let path = worktreePath else { return }
        isLoading = true
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.pull(path: path)
            self.isLoading = false
            if success {
                self.actionMessage = "Pull completed"
                self.refreshAll()
            } else {
                self.actionError = "Pull failed"
            }
        }
    }

    public func push() {
        guard let path = worktreePath else { return }
        guard hasRemote else {
            actionError = "No remote configured"
            return
        }
        isLoading = true
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.push(path: path)
            self.isLoading = false
            if success {
                self.actionMessage = "Push completed"
            } else {
                self.actionError = "Push failed"
            }
        }
    }

    public func fetch() {
        guard let path = worktreePath else { return }
        isLoading = true
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.fetch(path: path)
            self.isLoading = false
            if success {
                self.actionMessage = "Fetch completed"
                self.refreshAll()
            } else {
                self.actionError = "Fetch failed"
            }
        }
    }

    public func merge(branch: String, deleteWorktreeAfterMerge: Bool = false) {
        guard let path = worktreePath else { return }
        isLoading = true
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.merge(path: path, branch: branch)
            self.isLoading = false
            if success {
                self.actionMessage = "Merged '\(branch)'"
                self.refreshAll()

                if deleteWorktreeAfterMerge {
                    self.deleteWorktreeForMergedBranch(branch)
                }
            } else {
                self.actionError = "Merge with '\(branch)' failed"
            }
        }
    }

    private func deleteWorktreeForMergedBranch(_ branch: String) {
        guard let workspace = workspace, let project = workspace.activeProject else { return }
        let cleanBranch = branch.hasPrefix("refs/heads/") ? String(branch.dropFirst(11)) : branch
        if let worktree = project.worktrees.first(where: {
            let wtBranch = $0.branch.hasPrefix("refs/heads/") ? String($0.branch.dropFirst(11)) : $0.branch
            return wtBranch == cleanBranch && !$0.isMain
        }) {
            workspace.removeWorktree(projectId: project.id, worktreeId: worktree.id, deleteBranch: false)
        }
    }

    private func scheduleAutoDismiss() {
        autoDismissTask?.cancel()
        let currentMessage = actionMessage
        let currentError = actionError
        autoDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self = self else { return }
                if self.actionMessage != nil, self.actionMessage == currentMessage {
                    self.actionMessage = nil
                }
                if self.actionError != nil, self.actionError == currentError {
                    self.actionError = nil
                }
            }
        }
    }

    public func clearMessages() {
        actionMessage = nil
        actionError = nil
    }
}