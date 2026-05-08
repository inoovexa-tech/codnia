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
    @Published public var isCommitting: Bool = false
    @Published public var actionMessage: String? = nil
    @Published public var actionError: String? = nil

    private let git = GitService.shared
    private weak var workspace: WorkspaceService?
    private weak var editorVM: EditorViewModel?
    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?
    private var autoRefreshTask: Task<Void, Never>?

    public init(workspace: WorkspaceService, editorVM: EditorViewModel) {
        self.workspace = workspace
        self.editorVM = editorVM

        observeProjectChanges()
    }

    deinit {
        refreshTask?.cancel()
        autoRefreshTask?.cancel()
    }

    private func observeProjectChanges() {
        guard let workspace = workspace else { return }

        workspace.$activeProject
            .receive(on: RunLoop.main)
            .sink { [weak self] project in
                guard let self = self, let project = project else { return }
                self.stopAutoRefresh()
                self.refreshAll(for: project.path)
                self.startAutoRefresh()
            }
            .store(in: &cancellables)
    }

    private func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self?.refreshIfNeeded()
                }
            }
        }
    }

    private func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    private func refreshIfNeeded() {
        guard !isRefreshing, !isLoading, !isCommitting else { return }
        refreshAll()
    }

    public func refreshAll(for path: String? = nil) {
        refreshTask?.cancel()
        let projectPath = path ?? workspace?.activeProject?.path
        guard let projectPath = projectPath else { return }

        refreshTask = Task { [weak self] in
            guard let self = self else { return }
            self.isRefreshing = true
            self.isLoading = true

            async let status = self.git.getStatus(path: projectPath)
            async let branch = self.git.getBranch(path: projectPath)
            async let branches = self.git.getBranches(path: projectPath)

            let (statusResult, branchResult, branchesResult) = await (status, branch, branches)

            guard !Task.isCancelled else { return }

            self.statusEntries = statusResult
            self.stagedEntries = statusResult.filter { $0.isStaged }
            self.unstagedEntries = statusResult.filter { !$0.isStaged }
            self.currentBranch = branchResult
            self.branches = branchesResult
            self.isLoading = false
            self.isRefreshing = false
        }
    }

    // MARK: - Stage / Unstage

    public func stageFile(_ filePath: String) {
        guard let projectPath = workspace?.activeProject?.path else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.stageFile(path: projectPath, filePath: filePath)
            if success {
                self.refreshAll()
            } else {
                self.actionError = "Failed to stage file"
            }
        }
    }

    public func stageAll() {
        guard let projectPath = workspace?.activeProject?.path else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.stageAll(path: projectPath)
            if success {
                self.refreshAll()
            } else {
                self.actionError = "Failed to stage all files"
            }
        }
    }

    public func unstageFile(_ filePath: String) {
        guard let projectPath = workspace?.activeProject?.path else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.unstageFile(path: projectPath, filePath: filePath)
            if success {
                self.refreshAll()
            } else {
                self.actionError = "Failed to unstage file"
            }
        }
    }

    // MARK: - Discard

    public func discardFile(_ filePath: String) {
        guard let projectPath = workspace?.activeProject?.path else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.discardFileChanges(path: projectPath, filePath: filePath)
            if success {
                self.actionMessage = "Discarded changes in \(filePath)"
                self.refreshAll()
            } else {
                self.actionError = "Failed to discard changes"
            }
        }
    }

    // MARK: - Diff

    public func openDiff(for entry: GitStatusEntry) {
        guard let projectPath = workspace?.activeProject?.path,
              let editorVM = editorVM else { return }

        Task { [weak self] in
            guard let self = self else { return }
            
            // Load both versions of the file
            async let originalContent = self.git.getOriginalFileContent(
                path: projectPath,
                filePath: entry.filePath,
                staged: entry.isStaged
            )
            async let modifiedContent = self.git.getModifiedFileContent(
                path: projectPath,
                filePath: entry.filePath,
                staged: entry.isStaged
            )
            
            let (original, modified) = await (originalContent, modifiedContent)
            
            let originalLines = original?.components(separatedBy: .newlines) ?? []
            let modifiedLines = modified?.components(separatedBy: .newlines) ?? []
            
            // Compute diff using LCS algorithm
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
            // Store diff lines in diffData so they're preserved
            editorVM.diffData[tab.id] = diffLines
            editorVM.currentLanguage = "Diff"
            editorVM.objectWillChange.send()
        }
    }

    // MARK: - Commit

    public func commit() {
        guard let projectPath = workspace?.activeProject?.path else { return }
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
            guard let self = self else { return }
            let success = await self.git.commit(path: projectPath, message: message)
            self.isCommitting = false
            if success {
                self.commitMessage = ""
                self.actionMessage = "Committed successfully"
                self.refreshAll()
            } else {
                self.actionError = "Commit failed"
            }
        }
    }

    // MARK: - Branches

    public func createBranch(name: String) {
        guard let projectPath = workspace?.activeProject?.path else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.createBranch(path: projectPath, name: name)
            if success {
                self.actionMessage = "Created branch '\(name)'"
                self.refreshAll()
            } else {
                self.actionError = "Failed to create branch '\(name)'"
            }
        }
    }

    public func checkoutBranch(name: String) {
        guard let projectPath = workspace?.activeProject?.path else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.checkoutBranch(path: projectPath, name: name)
            if success {
                self.actionMessage = "Switched to branch '\(name)'"
                self.refreshAll()
            } else {
                self.actionError = "Failed to switch to branch '\(name)'"
            }
        }
    }

    // MARK: - Remote

    public func pull() {
        guard let projectPath = workspace?.activeProject?.path else { return }
        isLoading = true
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.pull(path: projectPath)
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
        guard let projectPath = workspace?.activeProject?.path else { return }
        isLoading = true
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.push(path: projectPath)
            self.isLoading = false
            if success {
                self.actionMessage = "Push completed"
            } else {
                self.actionError = "Push failed"
            }
        }
    }

    public func fetch() {
        guard let projectPath = workspace?.activeProject?.path else { return }
        isLoading = true
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.fetch(path: projectPath)
            self.isLoading = false
            if success {
                self.actionMessage = "Fetch completed"
                self.refreshAll()
            } else {
                self.actionError = "Fetch failed"
            }
        }
    }

    public func merge(branch: String) {
        guard let projectPath = workspace?.activeProject?.path else { return }
        isLoading = true
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.git.merge(path: projectPath, branch: branch)
            self.isLoading = false
            if success {
                self.actionMessage = "Merged '\(branch)'"
                self.refreshAll()
            } else {
                self.actionError = "Merge with '\(branch)' failed"
            }
        }
    }

    public func clearMessages() {
        actionMessage = nil
        actionError = nil
    }
}
