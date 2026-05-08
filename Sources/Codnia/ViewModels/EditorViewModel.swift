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
    @Published public var showInFileSearch: Bool = false

    private let workspace: WorkspaceService
    private let settings: SettingsService
    private let terminal: TerminalViewModel
    private let fs = FileSystemService.shared
    private var cancellables = Set<AnyCancellable>()
    private var fileContents: [String: String] = [:] // tabId -> original content
    @Published public var diffData: [String: [DiffLine]] = [:] // tabId -> diff lines
    private var autoSaveTimer: AnyCancellable?
    private var markdownPreviewTabs: Set<String> = []

    public var isCurrentTabMarkdown: Bool {
        currentTab?.language == "Markdown"
    }

    public var showMarkdownPreview: Bool {
        get { activeTabId.flatMap { markdownPreviewTabs.contains($0) } ?? false }
        set {
            if let id = activeTabId {
                if newValue { markdownPreviewTabs.insert(id) }
                else { markdownPreviewTabs.remove(id) }
                objectWillChange.send()
            }
        }
    }

    public init(workspace: WorkspaceService, settings: SettingsService, terminal: TerminalViewModel) {
        self.workspace = workspace
        self.settings = settings
        self.terminal = terminal
        terminal.workspace = workspace

        setupAutoSave()

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
        print("=== loadTabs from project: \(project.name) ===")
        print("  project.fileTabs count: \(project.fileTabs.count)")
        print("  fileContents keys: \(fileContents.keys)")
        
        // Always load tabs from project
        tabs = project.fileTabs
        terminal.tabs = project.terminalTabs
        activeTabId = project.activeTabId
        print("  activeTabId: \(activeTabId ?? "nil")")

        // Restore file contents for file tabs (only if not already loaded)
        for tab in project.fileTabs where (tab.type == .file || tab.type == .diff) && !tab.path.isEmpty {
            if fileContents[tab.id] == nil {
                if tab.type == .diff {
                    fileContents[tab.id] = ""
                } else {
                    let content = fs.readFile(path: tab.path)
                    fileContents[tab.id] = content
                }
            }
        }

        // Restore editor content for active tab
        if let activeId = activeTabId,
           let tab = tabs.first(where: { $0.id == activeId }),
           tab.type == .file || tab.type == .diff {
            let savedContent = fileContents[tab.id]
            print("  tab.id: \(tab.id)")
            print("  fileContents[tab.id] exists: \(savedContent != nil)")
            print("  fileContents[tab.id] length: \(savedContent?.count ?? 0)")
            if let saved = savedContent {
                editorContent = saved
                print("  Restored editorContent from fileContents, length: \(saved.count)")
            } else if !tab.path.isEmpty {
                let content = fs.readFile(path: tab.path)
                editorContent = content
                print("  Restored editorContent from disk, length: \(content.count)")
            }
            currentLanguage = tab.language
        }

        print("  Final editorContent length: \(editorContent.count)")
        // Force UI update
        objectWillChange.send()
    }

    private func setupAutoSave() {
        $editorContent
            .dropFirst()
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] content in
                guard let self = self else { return }
                guard self.settings.autoSave else { return }
                guard let tab = self.currentTab, tab.type == .file, !tab.path.isEmpty else { return }
                let original = self.fileContents[tab.id] ?? ""
                if content != original {
                    self.saveCurrentFile()
                }
            }
            .store(in: &cancellables)
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
        print("=== activateTab: \(id) ===")
        
        // Save current file content before switching (if it's a file tab)
        if let currentTabId = activeTabId,
           let currentTabIdx = tabs.firstIndex(where: { $0.id == currentTabId }),
           tabs[currentTabIdx].type == .file || tabs[currentTabIdx].type == .diff {
            fileContents[currentTabId] = editorContent
            print("  Saved current content: \(editorContent.count)")
        }
        
        activeTabId = id
        if let tab = tabs.first(where: { $0.id == id }) {
            if tab.type == .diff {
                // For diff tabs, use saved content only (never read from disk)
                if let savedContent = fileContents[tab.id] {
                    print("  Using savedContent for diff, length: \(savedContent.count)")
                    editorContent = savedContent
                } else {
                    editorContent = ""
                    print("  Diff tab has no saved content")
                }
                currentLanguage = "Diff"
            } else {
                // Use fileContents dictionary for unsaved content, fallback to reading from disk
                if let savedContent = fileContents[tab.id] {
                    print("  Using savedContent, length: \(savedContent.count)")
                    editorContent = savedContent
                } else {
                    let content = fs.readFile(path: tab.path)
                    print("  Reading from disk, length: \(content.count)")
                    editorContent = content
                    fileContents[tab.id] = content
                }
                currentLanguage = tab.language
                detectLanguage(from: tab.name)
            }
            print("  Final editorContent: \(editorContent.count)")
            // Force UI update
            objectWillChange.send()
            saveTabsToProject()
        }
    }

    public func closeTab(_ id: String) {
        if tabs.firstIndex(where: { $0.id == id }) != nil {
            tabs.removeAll { $0.id == id }
            fileContents.removeValue(forKey: id)
            diffData.removeValue(forKey: id)

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

    public func nextTab() {
        let all = allTabs
        guard let currentId = activeTabId, !all.isEmpty else {
            activeTabId = all.first?.id
            return
        }
        guard let currentIndex = all.firstIndex(where: { $0.id == currentId }) else { return }
        let nextIndex = (currentIndex + 1) % all.count
        let nextTab = all[nextIndex]
        if tabs.contains(where: { $0.id == nextTab.id }) {
            activateTab(nextTab.id)
        } else {
            activeTabId = nextTab.id
        }
    }

    public func previousTab() {
        let all = allTabs
        guard let currentId = activeTabId, !all.isEmpty else {
            activeTabId = all.first?.id
            return
        }
        guard let currentIndex = all.firstIndex(where: { $0.id == currentId }) else { return }
        let previousIndex = (currentIndex - 1 + all.count) % all.count
        let prevTab = all[previousIndex]
        if tabs.contains(where: { $0.id == prevTab.id }) {
            activateTab(prevTab.id)
        } else {
            activeTabId = prevTab.id
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
