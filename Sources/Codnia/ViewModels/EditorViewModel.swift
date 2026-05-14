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
    private var fileContents: [String: String] = [:]
    @Published public var diffData: [String: [DiffLine]] = [:]
    @Published public var queryResults: [String: QueryPageResult] = [:]
    @Published public var querySql: [String: String] = [:]
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

        if let worktree = workspace.activeProject?.activeWorktree {
            loadTabs(from: worktree)
        }

        var previousWorktreeId: String? = workspace.activeProject?.activeWorktree?.id
        workspace.$activeProject
            .receive(on: RunLoop.main)
            .sink { [weak self] project in
                guard let self = self else { return }

                if let prevId = previousWorktreeId,
                   let prevProject = self.workspace.projects.first(where: { $0.worktrees.contains { $0.id == prevId } }),
                   let prevWtIdx = prevProject.worktrees.firstIndex(where: { $0.id == prevId }),
                   let projIdx = self.workspace.projects.firstIndex(where: { $0.id == prevProject.id }) {
                    self.workspace.projects[projIdx].worktrees[prevWtIdx].fileTabs = self.tabs
                    self.workspace.projects[projIdx].worktrees[prevWtIdx].terminalTabs = self.terminal.tabs
                    self.workspace.projects[projIdx].worktrees[prevWtIdx].activeTabId = self.activeTabId
                    self.workspace.saveProjects()
                }

                if let activeProject = project, let worktree = activeProject.activeWorktree {
                    previousWorktreeId = worktree.id
                    self.loadTabs(from: worktree)
                } else {
                    self.tabs = []
                    self.terminal.tabs = []
                    self.activeTabId = nil
                }
            }
            .store(in: &cancellables)
    }

    private func loadTabs(from worktree: Worktree) {
        print("=== loadTabs from worktree: \(worktree.name) ===")
        print("  worktree.fileTabs count: \(worktree.fileTabs.count)")

        tabs = worktree.fileTabs
        terminal.tabs = worktree.terminalTabs
        terminal.setWorktreeMapping(tabs: worktree.terminalTabs, worktreeId: worktree.id)
        activeTabId = worktree.activeTabId

        for tab in worktree.fileTabs where (tab.type == .file || tab.type == .diff) && !tab.path.isEmpty {
            if fileContents[tab.id] == nil {
                if tab.type == .diff {
                    fileContents[tab.id] = ""
                } else {
                    let content = fs.readFile(path: tab.path)
                    fileContents[tab.id] = content
                }
            }
        }

        for tab in worktree.fileTabs where tab.type == .queryResult {
            if querySql[tab.id] == nil {
                querySql[tab.id] = tab.querySql ?? ""
            }
        }

        if let activeId = activeTabId,
           let tab = tabs.first(where: { $0.id == activeId }),
           tab.type == .file || tab.type == .diff {
            let savedContent = fileContents[tab.id]
            if let saved = savedContent {
                editorContent = saved
            } else if !tab.path.isEmpty {
                let content = fs.readFile(path: tab.path)
                editorContent = content
            }
            currentLanguage = tab.language
        }
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

    func saveTabsToWorktree() {
        guard let project = workspace.activeProject,
              let worktreeId = project.activeWorktreeId,
              let projIdx = workspace.projects.firstIndex(where: { $0.id == project.id }),
              let wtIdx = workspace.projects[projIdx].worktrees.firstIndex(where: { $0.id == worktreeId }) else { return }

        for i in tabs.indices where tabs[i].type == .queryResult {
            tabs[i].querySql = querySql[tabs[i].id]
        }

        workspace.projects[projIdx].worktrees[wtIdx].fileTabs = tabs
        workspace.projects[projIdx].worktrees[wtIdx].terminalTabs = terminal.tabs
        workspace.projects[projIdx].worktrees[wtIdx].activeTabId = activeTabId
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
        newFile(name: "Untitled", content: "")
    }

    public func newFile(name: String, content: String) {
        let tab = Tab(name: name, type: .file)
        tabs.append(tab)
        activeTabId = tab.id
        editorContent = content
        currentLanguage = detectedLanguageName(from: name)
        fileContents[tab.id] = content
        saveTabsToWorktree()
    }

    private func detectedLanguageName(from filename: String) -> String {
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        switch ext {
        case "swift": return "Swift"
        case "ts", "tsx": return "TypeScript"
        case "js", "jsx": return "JavaScript"
        case "rs": return "Rust"
        case "go": return "Go"
        case "py": return "Python"
        case "md", "markdown": return "Markdown"
        case "json": return "JSON"
        case "html", "htm": return "HTML"
        case "css", "scss": return "CSS"
        case "sh": return "Shell"
        case "c", "h": return "C"
        case "cpp", "hpp", "cc": return "C++"
        case "java": return "Java"
        case "kt": return "Kotlin"
        default: return "Plain Text"
        }
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
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()

        if isImageExtension(ext) {
            if let existing = tabs.first(where: { $0.path == path }) {
                activeTabId = existing.id
                saveTabsToWorktree()
                return
            }
            let tab = Tab(path: path, name: name, language: "Image", type: .image)
            tabs.append(tab)
            activeTabId = tab.id
            saveTabsToWorktree()
            return
        }

        if isPDFExtension(ext) {
            if let existing = tabs.first(where: { $0.path == path }) {
                activeTabId = existing.id
                saveTabsToWorktree()
                return
            }
            let tab = Tab(path: path, name: name, language: "PDF", type: .pdf)
            tabs.append(tab)
            activeTabId = tab.id
            saveTabsToWorktree()
            return
        }

        let language = languageForExtension(ext)
        let content = fs.readFile(path: path)

        if let existing = tabs.first(where: { $0.path == path }) {
            activeTabId = existing.id
            editorContent = content
            currentLanguage = language
            fileContents[existing.id] = content
            saveTabsToWorktree()
            return
        }

        let tab = Tab(path: path, name: name, language: language, type: .file)
        tabs.append(tab)
        activeTabId = tab.id
        editorContent = content
        currentLanguage = language
        fileContents[tab.id] = content
        detectLanguage(from: name)
        saveTabsToWorktree()
    }

    public func openFileFromTree(_ entry: FileEntry) {
        guard !entry.isDirectory else { return }
        openFile(entry.path)
    }

    // MARK: - Query Result Tabs

    public func newQueryTab(connectionId: String?) {
        let tab = Tab(name: "SQL Query", type: .queryResult, queryConnectionId: connectionId)
        tabs.append(tab)
        activeTabId = tab.id
        querySql[tab.id] = ""
        saveTabsToWorktree()
    }

    public func setQueryResult(_ result: QueryPageResult, forTab tabId: String) {
        var updated = queryResults
        updated[tabId] = result
        queryResults = updated
    }

    public func activateTab(_ id: String) {
        if let currentTabId = activeTabId,
           let currentTabIdx = tabs.firstIndex(where: { $0.id == currentTabId }),
           tabs[currentTabIdx].type == .file || tabs[currentTabIdx].type == .diff {
            fileContents[currentTabId] = editorContent
        }

        activeTabId = id
        if let tab = tabs.first(where: { $0.id == id }) {
            if tab.type == .diff {
                if let savedContent = fileContents[tab.id] {
                    editorContent = savedContent
                } else {
                    editorContent = ""
                }
                currentLanguage = "Diff"
            } else if tab.type == .queryResult {
                editorContent = ""
                currentLanguage = "SQL"
            } else {
                if let savedContent = fileContents[tab.id] {
                    editorContent = savedContent
                } else {
                    let content = fs.readFile(path: tab.path)
                    editorContent = content
                    fileContents[tab.id] = content
                }
                currentLanguage = tab.language
                detectLanguage(from: tab.name)
            }
            saveTabsToWorktree()
        }
    }

    public func closeTab(_ id: String) {
        if tabs.firstIndex(where: { $0.id == id }) != nil {
            tabs.removeAll { $0.id == id }
            fileContents.removeValue(forKey: id)
            diffData.removeValue(forKey: id)
            queryResults.removeValue(forKey: id)
            querySql.removeValue(forKey: id)

            if activeTabId == id {
                activeTabId = tabs.last?.id ?? terminal.tabs.last?.id
            }
            saveTabsToWorktree()
        } else if terminal.tabs.firstIndex(where: { $0.id == id }) != nil {
            terminal.closeTab(byId: id)
            if activeTabId == id {
                activeTabId = allTabs.last?.id
            }
            saveTabsToWorktree()
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
                saveTabsToWorktree()
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
                    saveTabsToWorktree()
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
        case "png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp": return "Image"
        case "pdf": return "PDF"
        default: return "Plain Text"
        }
    }

    public func isImageExtension(_ ext: String) -> Bool {
        let imageExts = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp"]
        return imageExts.contains(ext.lowercased())
    }

    public func isPDFExtension(_ ext: String) -> Bool {
        return ext.lowercased() == "pdf"
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
        let adjustedDestination = source < destination ? destination - 1 : destination
        tabs.insert(tab, at: adjustedDestination)
        saveTabsToWorktree()
    }
}