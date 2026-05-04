import Foundation
import Combine

@MainActor
public final class WorkspaceService: ObservableObject {
    @Published public var projects: [Project] = []
    @Published public var activeProject: Project? = nil
    @Published public var fileTree: [FileEntry] = []
    @Published public var branches: [String: String] = [:]

    public init() {
        loadProjects()
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
            // Load active
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
        }
    }

    public func removeProject(id: String) {
        projects.removeAll { $0.id == id }
        if activeProject?.id == id {
            activeProject = projects.first
            refreshFileTree()
            if let p = activeProject { loadBranch(for: p) }
        }
        saveProjects()
    }

    public func renameProject(id: String, newName: String) {
        if let idx = projects.firstIndex(where: { $0.id == id }) {
            projects[idx].name = newName
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
        GitService.shared.getBranch(path: project.path) { [weak self] branch in
            DispatchQueue.main.async {
                self?.branches[project.id] = branch
            }
        }
    }

    public func getBranch(forProjectId id: String) -> String {
        branches[id] ?? "main"
    }
}
