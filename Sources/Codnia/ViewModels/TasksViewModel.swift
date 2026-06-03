import Foundation
import Combine
import OSLog

@MainActor
public final class TasksViewModel: ObservableObject {
    @Published public var tasks: [TaskItem] = []
    @Published public var searchText: String = ""
    @Published public var selectedTags: Set<String> = []

    private let workspace: WorkspaceService
    private var cancellables = Set<AnyCancellable>()
    private let descriptionSaveSubject = PassthroughSubject<TaskItem, Never>()
    private var tasksFileObserver: DispatchSourceFileSystemObject?

    private var tasksFilePath: String? {
        guard let project = workspace.activeProject else { return nil }
        return (project.path as NSString).appendingPathComponent(".codnia/tasks.json")
    }

    public var allTags: [String] {
        let tags = Set(tasks.flatMap { $0.tags })
        return tags.sorted()
    }

    public var filteredTasks: [TaskItem] {
        var result = tasks

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) || $0.description.lowercased().contains(q)
            }
        }

        if !selectedTags.isEmpty {
            result = result.filter { task in
                !selectedTags.isDisjoint(with: Set(task.tags))
            }
        }

        return result
    }

    public init(workspace: WorkspaceService) {
        self.workspace = workspace
        loadFromDisk()

        workspace.$activeProject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadFromDisk()
                self?.updateFileObserver()
            }
            .store(in: &cancellables)

        descriptionSaveSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveToDisk()
            }
            .store(in: &cancellables)

        updateFileObserver()
    }

    deinit {
        tasksFileObserver?.cancel()
        tasksFileObserver = nil
    }

    // MARK: - File Observer

    private func setupDirectoryObserver(for dirPath: String) {
        tasksFileObserver?.cancel()

        let fd = open(dirPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            self?.loadFromDisk()
        }

        source.setCancelHandler { close(fd) }
        source.resume()
        tasksFileObserver = source
    }

    private func updateFileObserver() {
        tasksFileObserver?.cancel()
        tasksFileObserver = nil
        guard let path = tasksFilePath else { return }
        let dirPath = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
        setupDirectoryObserver(for: dirPath)
    }

    // MARK: - CRUD

    public func addTask(title: String, description: String = "", tags: [String] = [], priority: TaskPriority = .medium) {
        let task = TaskItem(
            title: title,
            description: description,
            tags: tags,
            priority: priority
        )
        tasks.append(task)
        saveToDisk()
    }

    public func updateTask(_ task: TaskItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var updated = task
        updated.updatedAt = Date()
        tasks[idx] = updated
        saveToDisk()
    }

    public func deleteTask(id: String) {
        tasks.removeAll { $0.id == id }
        saveToDisk()
    }

    public func toggleTask(id: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].isCompleted.toggle()
        tasks[idx].updatedAt = Date()
        saveToDisk()
    }

    public func renameTag(_ oldName: String, to newName: String) {
        for i in tasks.indices {
            if let idx = tasks[i].tags.firstIndex(of: oldName) {
                tasks[i].tags[idx] = newName
                tasks[i].updatedAt = Date()
            }
        }
        if selectedTags.contains(oldName) {
            selectedTags.remove(oldName)
            selectedTags.insert(newName)
        }
        saveToDisk()
    }

    public func moveTask(from source: Int, to destination: Int, using visible: [TaskItem]) {
        guard source < visible.count, destination <= visible.count, source != destination else { return }
        let movingId = visible[source].id
        guard let actualSource = tasks.firstIndex(where: { $0.id == movingId }) else { return }

        if destination == visible.count {
            let task = tasks.remove(at: actualSource)
            tasks.append(task)
            saveToDisk()
            return
        }

        let targetId = visible[destination].id
        guard let actualDestination = tasks.firstIndex(where: { $0.id == targetId }) else { return }

        let task = tasks.remove(at: actualSource)
        let adjustedDest = actualSource < actualDestination ? actualDestination - 1 : actualDestination
        tasks.insert(task, at: adjustedDest)
        saveToDisk()
    }

    public func duplicateTask(id: String) {
        guard let original = tasks.first(where: { $0.id == id }) else { return }
        let copy = TaskItem(
            title: "\(original.title) (copy)",
            description: original.description,
            tags: original.tags,
            priority: original.priority
        )
        tasks.append(copy)
        saveToDisk()
    }

    public func restoreTask(_ task: TaskItem) {
        tasks.append(task)
        saveToDisk()
    }

    public func removeTagFromAll(_ tag: String) {
        for i in tasks.indices where tasks[i].tags.contains(tag) {
            tasks[i].tags.removeAll { $0 == tag }
            tasks[i].updatedAt = Date()
        }
        selectedTags.remove(tag)
        saveToDisk()
    }

    public func updateDescription(_ task: TaskItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].description = task.description
        tasks[idx].updatedAt = Date()
        descriptionSaveSubject.send(task)
    }

    // MARK: - Persistence

    public func loadFromDisk() {
        guard let path = tasksFilePath else {
            tasks = []
            return
        }
        let fm = FileManager.default
        guard fm.fileExists(atPath: path),
              let data = fm.contents(atPath: path)
        else {
            tasks = []
            return
        }
        do {
            tasks = try JSONDecoder().decode([TaskItem].self, from: data)
        } catch {
            let backupPath = path + ".backup"
            if let backupData = fm.contents(atPath: backupPath),
               let decoded = try? JSONDecoder().decode([TaskItem].self, from: backupData)
            {
                tasks = decoded
                os_log("Codnia: Loaded tasks from backup — main file corrupted: %{public}@",
                       log: .default, type: .error, error.localizedDescription)
            } else {
                tasks = []
                os_log("Codnia: Failed to load tasks and no valid backup found: %{public}@",
                       log: .default, type: .error, error.localizedDescription)
            }
        }
    }

    public func saveToDisk() {
        guard let path = tasksFilePath else { return }
        let fm = FileManager.default
        let dir = (path as NSString).deletingLastPathComponent
        do {
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(tasks)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            let backupPath = path + ".backup"
            try data.write(to: URL(fileURLWithPath: backupPath), options: .atomic)
        } catch {
            os_log("Codnia: Failed to save tasks: %{public}@",
                   log: .default, type: .error, error.localizedDescription)
        }
    }
}
