import SwiftUI
import Combine

@MainActor
public final class EditorViewModel: ObservableObject {
    @Published public var tabs: [Tab] = []
    @Published public var activeTabId: String? = nil
    @Published public var cursorPosition: String = "Ln 1, Col 1"
    @Published public var currentLanguage: String = "Plain Text"
    @Published public var editorContent: String = ""
    @Published public var showGlobalSearch: Bool = false

    private let workspace: WorkspaceService
    private let settings: SettingsService
    private let terminal: TerminalViewModel
    private let fs = FileSystemService.shared
    private var cancellables = Set<AnyCancellable>()
    private var fileContents: [String: String] = [:] // tabId -> original content

    public init(workspace: WorkspaceService, settings: SettingsService, terminal: TerminalViewModel) {
        self.workspace = workspace
        self.settings = settings
        self.terminal = terminal
        terminal.workspace = workspace

        // Load tabs from active project
        if let project = workspace.activeProject {
            loadTabs(from: project)
        }

        // Observe project changes
        var previousProject: Project? = workspace.activeProject
        workspace.$activeProject
            .receive(on: RunLoop.main)
            .sink { [weak self] project in
                guard let self = self else { return }
                // Save current tabs to previous project before switching
                if let prev = previousProject,
                   let idx = workspace.projects.firstIndex(where: { $0.id == prev.id }) {
                    workspace.projects[idx].fileTabs = self.tabs
                    workspace.projects[idx].terminalTabs = self.terminal.tabs
                    workspace.projects[idx].activeTabId = self.activeTabId
                    workspace.saveProjects()
                }
                previousProject = project
                if let project = project {
                    self.loadTabs(from: project)
                } else {
                    self.tabs = []
                    self.terminal.tabs = []
                    self.activeTabId = nil
                }
            }
            .store(in: &cancellables)
    }

    private func loadTabs(from project: Project) {
        // Always load tabs from project
        tabs = project.fileTabs
        terminal.tabs = project.terminalTabs
        activeTabId = project.activeTabId

        // Restore file contents for file tabs
        for tab in project.fileTabs where tab.type == .file && !tab.path.isEmpty {
            let content = fs.readFile(path: tab.path)
            fileContents[tab.id] = content
        }

        // Force UI update
        objectWillChange.send()
    }

    private func saveTabsToProject() {
        guard let projectId = workspace.activeProject?.id,
              let index = workspace.projects.firstIndex(where: { $0.id == projectId }) else { return }

        workspace.projects[index].fileTabs = tabs
        workspace.projects[index].terminalTabs = terminal.tabs
        workspace.projects[index].activeTabId = activeTabId
        workspace.saveProjects()
    }

    public var allTabs: [Tab] {
        tabs + terminal.tabs
    }

    public var currentTab: Tab? {
        guard let id = activeTabId else { return nil }
        return allTabs.first { $0.id == id }
    }

    public func newFile() {
        let tab = Tab(name: "Untitled", type: .file)
        tabs.append(tab)
        activeTabId = tab.id
        editorContent = ""
        currentLanguage = "Plain Text"
        fileContents[tab.id] = ""
        saveTabsToProject()
    }

    public func openFileDialog() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            openFile(url.path)
        }
    }

    public func openFile(_ path: String) {
        let name = URL(fileURLWithPath: path).lastPathComponent
        // Detect language
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        let language = languageForExtension(ext)
        let content = fs.readFile(path: path)

        if let existing = tabs.first(where: { $0.path == path }) {
            activeTabId = existing.id
            editorContent = content
            currentLanguage = language
            fileContents[existing.id] = content
            objectWillChange.send()
            saveTabsToProject()
            return
        }

        let tab = Tab(path: path, name: name, language: language, type: .file)
        tabs.append(tab)
        activeTabId = tab.id
        editorContent = content
        currentLanguage = language
        fileContents[tab.id] = content
        detectLanguage(from: name)
        objectWillChange.send()
        saveTabsToProject()
    }

    public func openFileFromTree(_ entry: FileEntry) {
        guard !entry.isDirectory else { return }
        openFile(entry.path)
    }

    public func activateTab(_ id: String) {
        activeTabId = id
        if let tab = tabs.first(where: { $0.id == id }) {
            // Use fileContents dictionary for unsaved content, fallback to reading from disk
            if let savedContent = fileContents[tab.id] {
                editorContent = savedContent
            } else {
                let content = fs.readFile(path: tab.path)
                editorContent = content
                fileContents[tab.id] = content
            }
            currentLanguage = tab.language
            detectLanguage(from: tab.name)
            // Force UI update
            objectWillChange.send()
            saveTabsToProject()
        }
    }

    public func closeTab(_ id: String) {
        if tabs.firstIndex(where: { $0.id == id }) != nil {
            tabs.removeAll { $0.id == id }
            fileContents.removeValue(forKey: id)

            if activeTabId == id {
                activeTabId = tabs.last?.id ?? terminal.tabs.last?.id
            }
            saveTabsToProject()
        } else if terminal.tabs.first(where: { $0.id == id }) != nil {
            terminal.closeTab(byId: id)
            if activeTabId == id {
                activeTabId = allTabs.last?.id
            }
            saveTabsToProject()
        }
    }

    public func closeCurrentTab() {
        if let id = activeTabId {
            closeTab(id)
        }
    }

    public func markModified(tabId: String) {
        if let idx = tabs.firstIndex(where: { $0.id == tabId }) {
            let original = fileContents[tabId] ?? ""
            tabs[idx].isModified = (editorContent != original)
        }
    }

    public func saveCurrentFile() {
        guard let tab = currentTab, tab.type == .file else { return }
        if tab.path.isEmpty {
            saveCurrentFileAs()
            return
        }
        do {
            try fs.writeFile(path: tab.path, content: editorContent)
            fileContents[tab.id] = editorContent
            if let idx = tabs.firstIndex(where: { $0.id == tab.id }) {
                tabs[idx].isModified = false
                saveTabsToProject()
            }
        } catch {
            print("Save failed: \(error)")
        }
    }

    public func saveCurrentFileAs() {
        guard let tab = currentTab, tab.type == .file else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = tab.name
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try fs.writeFile(path: url.path, content: editorContent)
                fileContents[tab.id] = editorContent
                if let idx = tabs.firstIndex(where: { $0.id == tab.id }) {
                    tabs[idx].path = url.path
                    tabs[idx].name = url.lastPathComponent
                    tabs[idx].isModified = false
                    saveTabsToProject()
                }
            } catch {
                print("Save As failed: \(error)")
            }
        }
    }

    public func createTerminalTab(type: TabType = .terminal) {
        let tab = terminal.createTerminalTab(type: type)
        activeTabId = tab.id
    }

    public func detectLanguage(from filename: String) {
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        currentLanguage = languageForExtension(ext)
    }

    public func languageForExtension(_ ext: String) -> String {
        switch ext {
        case "rs": return "Rust"
        case "ts", "tsx": return "TypeScript"
        case "js", "jsx": return "JavaScript"
        case "json": return "JSON"
        case "html", "htm": return "HTML"
        case "css", "scss": return "CSS"
        case "md", "markdown": return "Markdown"
        case "swift": return "Swift"
        case "py": return "Python"
        case "go": return "Go"
        case "sh": return "Shell"
        case "yaml", "yml": return "YAML"
        case "toml": return "TOML"
        default: return "Plain Text"
        }
    }

    public func updateCursorPosition(line: Int, column: Int) {
        cursorPosition = "Ln \(line), Col \(column)"
    }

    public func moveTab(from source: Int, to destination: Int) {
        guard source < tabs.count, destination < tabs.count, source != destination else { return }
        let tab = tabs.remove(at: source)
        // Adjust destination if needed
        let adjustedDestination = source < destination ? destination - 1 : destination
        tabs.insert(tab, at: adjustedDestination)
        saveTabsToProject()
    }
}
