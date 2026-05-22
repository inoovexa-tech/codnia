import Foundation
import Combine

@MainActor
public final class WorkspaceService: ObservableObject {
    @Published public var projects: [Project] = []
    @Published public var activeProject: Project? = nil
    @Published public var fileTree: [FileEntry] = []
    @Published public var branches: [String: String] = [:]
    @Published public var changesCount: [String: (added: Int, deleted: Int)] = [:]
    @Published public var worktreeRemoveError: String?

    private var refreshTask: Task<Void, Never>?
    private var gitTasks: [String: Task<Void, Never>] = [:]
    private var fileObservers: [String: DispatchSourceFileSystemObject] = [:]

    public init() {
        loadProjects()
        startAutoRefresh()
    }

    deinit {
        refreshTask?.cancel()
        gitTasks.values.forEach { $0.cancel() }
        gitTasks.removeAll()
        fileObservers.values.forEach { $0.cancel() }
        fileObservers.removeAll()
    }

    public func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        gitTasks.values.forEach { $0.cancel() }
        gitTasks.removeAll()
        fileObservers.values.forEach { $0.cancel() }
        fileObservers.removeAll()
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshAllChanges()
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    private func setupFileObserver(for project: Project) {
        guard let worktree = project.activeWorktree else { return }
        let fd = open(worktree.path, O_EVTONLY)
        guard fd >= 0 else { return }

        fileObservers[project.id]?.cancel()

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .global(qos: .userInitiated)
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.refreshChanges(for: project)
            }
        }

        source.setCancelHandler { close(fd) }
        source.resume()
        fileObservers[project.id] = source
    }

    private func refreshChanges(for project: Project) {
        gitTasks[project.id]?.cancel()
        gitTasks[project.id] = Task { [weak self] in
            guard let worktree = project.activeWorktree else { return }
            let result = await GitService.shared.getChangesCount(path: worktree.path)
            guard !Task.isCancelled else { return }
            self?.changesCount[worktree.id] = result
        }
    }

    private func cleanupFileObserver(for projectId: String) {
        fileObservers[projectId]?.cancel()
        fileObservers.removeValue(forKey: projectId)
    }

    private func refreshAllChanges() async {
        await withTaskGroup(of: Void.self) { group in
            for project in projects {
                let worktreeId = project.activeWorktree?.id
                let worktreePath = project.activeWorktree?.path
                guard let wtId = worktreeId, let wtPath = worktreePath else { continue }
                group.addTask {
                    let result = await GitService.shared.getChangesCount(path: wtPath)
                    await MainActor.run {
                        self.changesCount[wtId] = result
                    }
                }
            }
        }
    }

    public func loadProjects() {
        let fm = FileManager.default
        let baseURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Codnia", isDirectory: true)
        let workspaceFile = baseURL.appendingPathComponent("workspace.json")

        if fm.fileExists(atPath: workspaceFile.path),
           let data = try? Data(contentsOf: workspaceFile),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            projects = decoded
            for project in projects {
                setupFileObserver(for: project)
                refreshChanges(for: project)
            }
            let activeFile = baseURL.appendingPathComponent("active-project.json")
            if let activeData = try? Data(contentsOf: activeFile),
               let activeId = String(data: activeData, encoding: .utf8),
               let active = projects.first(where: { $0.id == activeId }) {
                self.activeProject = active
                refreshFileTree()
                loadBranch(for: active)
            }
        }
    }

    public func saveProjects() {
        let fm = FileManager.default
        let baseURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Codnia", isDirectory: true)
        try? fm.createDirectory(at: baseURL, withIntermediateDirectories: true)

        if let data = try? JSONEncoder().encode(projects) {
            try? data.write(to: baseURL.appendingPathComponent("workspace.json"))
        }
        if let active = activeProject,
           let data = active.id.data(using: .utf8) {
            try? data.write(to: baseURL.appendingPathComponent("active-project.json"))
        } else {
            try? fm.removeItem(at: baseURL.appendingPathComponent("active-project.json"))
        }
    }

    public func addProject(path: String) {
        Log.write("[WorkspaceService] addProject path=\(path)")
        let name = URL(fileURLWithPath: path).lastPathComponent

        if let existing = projects.first(where: { $0.path == path }) {
            Log.write("[WorkspaceService] project already exists, activating")
            activeProject = existing
            saveProjects()
            refreshFileTree()
            loadBranch(for: existing)
            return
        }

        let mainWorktree = Worktree(
            name: "main",
            path: path,
            branch: "main",
            isMain: true
        )

        let project = Project(
            name: name,
            path: path,
            worktrees: [mainWorktree],
            activeWorktreeId: mainWorktree.id
        )

        Log.write("[WorkspaceService] creating project id=\(project.id)")
        projects.append(project)
        activeProject = project
        saveProjects()
        RecentProjectsService.shared.add(path)
        refreshFileTree()
        loadBranch(for: project)
        setupFileObserver(for: project)
        refreshChanges(for: project)
        Log.write("[WorkspaceService] addProject done, count=\(projects.count)")
    }

    public func removeProject(id: String) {
        cleanupFileObserver(for: id)
        gitTasks[id]?.cancel()
        gitTasks.removeValue(forKey: id)
        projects.removeAll { $0.id == id }
        changesCount.removeValue(forKey: id)
        if activeProject?.id == id {
            activeProject = projects.first
            refreshFileTree()
            if let p = activeProject { loadBranch(for: p) }
        }
        saveProjects()
    }

    public func renameProject(id: String, newName: String, renameDirectory: Bool = false) {
        if let idx = projects.firstIndex(where: { $0.id == id }) {
            let oldPath = projects[idx].path
            projects[idx].name = newName

            if renameDirectory {
                let parentDir = URL(fileURLWithPath: oldPath).deletingLastPathComponent().path
                let newPath = "\(parentDir)/\(newName)"
                do {
                    try FileManager.default.moveItem(atPath: oldPath, toPath: newPath)
                    projects[idx].path = newPath
                } catch {
                    
                }
            }

            saveProjects()
        }
    }

    public func updateProjectIcon(id: String, iconPath: String?) {
        if let idx = projects.firstIndex(where: { $0.id == id }) {
            projects[idx].customIconPath = iconPath
            if activeProject?.id == id {
                activeProject = projects[idx]
            }
            objectWillChange.send()
            saveProjects()
        }
    }

    public func setWorktreesExpanded(projectId: String, expanded: Bool) {
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        var updated = projects
        updated[idx].isWorktreesExpanded = expanded
        projects = updated
        saveProjects()
    }

    public func setActiveProject(id: String) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[idx].isWorktreesExpanded.toggle()
        let project = projects[idx]
        activeProject = project
        saveProjects()
        refreshFileTree()
        loadBranch(for: project)
        syncWorktreesWithGit(for: project)
    }

    public func syncWorktreesWithGit(for project: Project) {
        guard let projIdx = projects.firstIndex(where: { $0.id == project.id }) else { return }

        Task {
            let gitWorktrees = await GitService.shared.listWorktrees(path: project.path)
            await MainActor.run {
                let existingPaths = Set(self.projects[projIdx].worktrees.map { $0.path })

                for gitWt in gitWorktrees {
                    if existingPaths.contains(gitWt.path) {
                        if let idx = self.projects[projIdx].worktrees.firstIndex(where: { $0.path == gitWt.path }),
                           self.projects[projIdx].worktrees[idx].branch != gitWt.branch {
                            self.projects[projIdx].worktrees[idx].branch = gitWt.branch
                        }
                        continue
                    }
                    let newWorktree = Worktree(
                        name: gitWt.branch,
                        path: gitWt.path,
                        branch: gitWt.branch,
                        isMain: gitWt.isMain
                    )
                    self.projects[projIdx].worktrees.append(newWorktree)
                }

                if self.activeProject?.id == project.id {
                    self.objectWillChange.send()
                    self.saveProjects()
                }
            }
        }
    }

    public func setActiveWorktree(projectId: String, worktreeId: String) {
        guard let projIdx = projects.firstIndex(where: { $0.id == projectId }),
              projects[projIdx].worktrees.contains(where: { $0.id == worktreeId }) else { return }

        projects[projIdx].activeWorktreeId = worktreeId
        projects[projIdx].isWorktreesExpanded = true
        activeProject = projects[projIdx]

        saveProjects()
        refreshFileTree()
        loadBranch(for: projects[projIdx])
        setupFileObserver(for: projects[projIdx])
        refreshChanges(for: projects[projIdx])
    }

    public func addWorktree(projectId: String, branch: String, worktreePath: String, createBranch: Bool, deleteBranchOnRemove: Bool) {
        let projectPath: String
        if let proj = projects.first(where: { $0.id == projectId }) {
            projectPath = proj.path
        } else { return }

        Task {
            let success = await GitService.shared.addWorktree(
                projectPath: projectPath,
                branch: branch,
                worktreePath: worktreePath,
                createBranch: createBranch
            )

            if success {
                let newWorktree = Worktree(
                    name: branch,
                    path: worktreePath,
                    branch: branch,
                    isMain: false
                )

                await MainActor.run {
                    guard let idx = self.projects.firstIndex(where: { $0.id == projectId }) else { return }
                    var updated = self.projects
                    updated[idx].worktrees.append(newWorktree)
                    self.projects = updated
                    self.saveProjects()
                }
            }
        }
    }

    public func reloadProjects() {
        loadProjects()
        objectWillChange.send()
    }

    public func removeWorktree(projectId: String, worktreeId: String, deleteBranch: Bool) {
        guard let projIdx = projects.firstIndex(where: { $0.id == projectId }),
              let wtIdx = projects[projIdx].worktrees.firstIndex(where: { $0.id == worktreeId }),
              !projects[projIdx].worktrees[wtIdx].isMain else { return }

        let worktree = projects[projIdx].worktrees[wtIdx]
        let project = projects[projIdx]

        Task {
            let (success, errorMsg) = await GitService.shared.removeWorktree(
                projectPath: project.path,
                worktreePath: worktree.path,
                worktreeBranch: worktree.branch,
                deleteBranch: deleteBranch
            )

            guard success else {
                await MainActor.run {
                    self.worktreeRemoveError = errorMsg
                }
                return
            }

            await MainActor.run {
                self.worktreeRemoveError = nil
            }

            await MainActor.run {
                self.projects[projIdx].worktrees.remove(at: wtIdx)
                self.changesCount.removeValue(forKey: worktreeId)

                if project.activeWorktreeId == worktreeId {
                    if let mainWt = self.projects[projIdx].worktrees.first(where: { $0.isMain }) {
                        self.projects[projIdx].activeWorktreeId = mainWt.id
                    } else {
                        self.projects[projIdx].activeWorktreeId = self.projects[projIdx].worktrees.first?.id
                    }
                }

                if self.activeProject?.id == projectId {
                    self.activeProject = self.projects[projIdx]
                    self.refreshFileTree()
                    self.loadBranch(for: self.projects[projIdx])
                }

                self.saveProjects()
            }
        }
    }

    public func nextProject() {
        guard !projects.isEmpty else { return }
        guard let current = activeProject else {
            setActiveProject(id: projects[0].id)
            return
        }
        guard let index = projects.firstIndex(where: { $0.id == current.id }) else { return }
        let nextIndex = (index + 1) % projects.count
        setActiveProject(id: projects[nextIndex].id)
    }

    public func previousProject() {
        guard !projects.isEmpty else { return }
        guard let current = activeProject else {
            setActiveProject(id: projects[0].id)
            return
        }
        guard let index = projects.firstIndex(where: { $0.id == current.id }) else { return }
        let previousIndex = (index - 1 + projects.count) % projects.count
        setActiveProject(id: projects[previousIndex].id)
    }

    public func refreshFileTree() {
        guard let worktree = activeProject?.activeWorktree else {
            fileTree = []
            return
        }
        fileTree = FileSystemService.shared.listDirectory(path: worktree.path)
    }

    public var currentWorkspacePath: String {
        activeProject?.activeWorktree?.path ?? ""
    }

    public func toggleSidebar() {
    }

    private func loadBranch(for project: Project) {
        guard let worktree = project.activeWorktree else { return }
        gitTasks[project.id]?.cancel()
        gitTasks[project.id] = Task { [weak self] in
            async let branch = GitService.shared.getBranch(path: worktree.path)
            async let changes = GitService.shared.getChangesCount(path: worktree.path)
            let (b, c) = await (branch, changes)
            guard !Task.isCancelled else { return }
            self?.branches[worktree.id] = b
            self?.changesCount[worktree.id] = c
        }
    }

    public func getBranch(forWorktreeId id: String) -> String {
        branches[id] ?? "main"
    }

    public func getBranch(forProjectId id: String) -> String {
        guard let project = projects.first(where: { $0.id == id }),
              let worktree = project.activeWorktree else { return "main" }
        return branches[worktree.id] ?? "main"
    }

    public func getChangesCount(forWorktreeId id: String) -> (added: Int, deleted: Int) {
        changesCount[id] ?? (added: 0, deleted: 0)
    }

    public func getChangesCount(forProjectId id: String) -> (added: Int, deleted: Int) {
        guard let project = projects.first(where: { $0.id == id }),
              let worktree = project.activeWorktree else { return (added: 0, deleted: 0) }
        return changesCount[worktree.id] ?? (added: 0, deleted: 0)
    }
}