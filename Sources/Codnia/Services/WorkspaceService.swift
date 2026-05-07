import Foundation
import Combine

@MainActor
public final class WorkspaceService: ObservableObject {
    @Published public var projects: [Project] = []
    @Published public var activeProject: Project? = nil
    @Published public var fileTree: [FileEntry] = []
    @Published public var branches: [String: String] = [:]
    @Published public var changesCount: [String: (added: Int, deleted: Int)] = [:]
    @Published public var projectRunningStates: [String: Bool] = [:]

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
                await self?.refreshRunningStates()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func setupFileObserver(for project: Project) {
        let fd = open(project.path, O_EVTONLY)
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
        // Cancel stale task for this project before starting a new one
        gitTasks[project.id]?.cancel()
        gitTasks[project.id] = Task { [weak self] in
            let result = await GitService.shared.getChangesCount(path: project.path)
            guard !Task.isCancelled else { return }
            self?.changesCount[project.id] = result
        }
    }

    private func cleanupFileObserver(for projectId: String) {
        fileObservers[projectId]?.cancel()
        fileObservers.removeValue(forKey: projectId)
    }

    private func refreshAllChanges() async {
        await withTaskGroup(of: Void.self) { group in
            for project in projects {
                group.addTask { [weak self] in
                    let result = await GitService.shared.getChangesCount(path: project.path)
                    await MainActor.run {
                        self?.changesCount[project.id] = result
                    }
                }
            }
        }
    }

    private func refreshRunningStates() async {
        for project in projects {
            let hasAITerminal = project.terminalTabs.contains {
                $0.type == .opencode || $0.type == .claude || $0.type == .codex
            }
            projectRunningStates[project.id] = hasAITerminal
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
        let name = URL(fileURLWithPath: path).lastPathComponent
        let project = Project(name: name, path: path)
        if !projects.contains(where: { $0.path == path }) {
            projects.append(project)
            activeProject = project
            saveProjects()
            RecentProjectsService.shared.add(path)
            refreshFileTree()
            loadBranch(for: project)
            setupFileObserver(for: project)
            refreshChanges(for: project)
        }
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
                    print("Failed to rename directory: \(error)")
                }
            }

            saveProjects()
        }
    }

    public func updateProjectIcon(id: String, iconPath: String?) {
        if let idx = projects.firstIndex(where: { $0.id == id }) {
            let oldProject = projects[idx]
            let updatedProject = Project(
                id: oldProject.id,
                name: oldProject.name,
                path: oldProject.path,
                createdAt: oldProject.createdAt,
                fileTabs: oldProject.fileTabs,
                terminalTabs: oldProject.terminalTabs,
                activeTabId: oldProject.activeTabId,
                customIconPath: iconPath
            )
            projects[idx] = updatedProject
            if activeProject?.id == id {
                activeProject = updatedProject
            }
            objectWillChange.send()
            saveProjects()
        }
    }

    public func setActiveProject(id: String) {
        if let project = projects.first(where: { $0.id == id }) {
            activeProject = project
            saveProjects()
            refreshFileTree()
            loadBranch(for: project)
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
        guard let path = activeProject?.path else {
            fileTree = []
            return
        }
        fileTree = FileSystemService.shared.listDirectory(path: path)
    }

    public func toggleSidebar() {
        // Handled by view layer binding
    }

    private func loadBranch(for project: Project) {
        gitTasks[project.id]?.cancel()
        gitTasks[project.id] = Task { [weak self] in
            async let branch = GitService.shared.getBranch(path: project.path)
            async let changes = GitService.shared.getChangesCount(path: project.path)
            let (b, c) = await (branch, changes)
            guard !Task.isCancelled else { return }
            self?.branches[project.id] = b
            self?.changesCount[project.id] = c
        }
    }

    public func getBranch(forProjectId id: String) -> String {
        branches[id] ?? "main"
    }

    public func getChangesCount(forProjectId id: String) -> (added: Int, deleted: Int) {
        changesCount[id] ?? (added: 0, deleted: 0)
    }
}
