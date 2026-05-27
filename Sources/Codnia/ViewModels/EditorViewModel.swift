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
    @Published public var showInFileSearch: Bool = false {
        didSet {
            if !showInFileSearch {
                inFileSearchQuery = ""
                inFileSearchResults = []
                inFileSearchCurrentIndex = 0
            }
        }
    }
    @Published public var searchHighlightQuery: String = ""
    @Published public var searchHighlightRanges: [NSRange] = []
    @Published public var searchHighlightIndex: Int = 0
    @Published public var inFileSearchQuery: String = ""
    @Published public var inFileSearchResults: [NSRange] = []
    @Published public var inFileSearchCurrentIndex: Int = 0

    private let workspace: WorkspaceService
    private let settings: SettingsService
    private let terminal: TerminalViewModel
    private let fs = FileSystemService.shared
    private var cancellables = Set<AnyCancellable>()
    public var splitVM: SplitViewModel?
    public var fileContents: [String: String] = [:]
    @Published public var diffData: [String: [DiffLine]] = [:]
    @Published public var queryResults: [String: QueryPageResult] = [:]
    @Published public var querySql: [String: String] = [:]
    @Published public var browserURLs: [String: String] = [:]
    @Published public var browserTitles: [String: String] = [:]
    @Published var restApiTabStates: [String: RESTApiTabState] = [:]
    @Published var queryHistory: [String: [QueryHistoryItem]] = [:]
    private var autoSaveTimer: AnyCancellable?
    private var markdownPreviewTabs: Set<String> = []
    private var htmlPreviewTabs: Set<String> = []
    private var autoSaveTabId: String?

    public var isCurrentTabMarkdown: Bool {
        currentTab?.language == "Markdown"
    }

    public var isCurrentTabHTML: Bool {
        currentTab?.language == "HTML"
    }

    public var modifiedFilePaths: Set<String> {
        Set(tabs.filter(\.isModified).map(\.path).filter { !$0.isEmpty })
    }

    private struct PendingOpenFile {
        let path: String
        let projectId: String
        let worktreeId: String
        let searchQuery: String
    }
    private var pendingOpenFile: PendingOpenFile?

    public func openFileInWorktree(path: String, projectId: String, worktreeId: String, searchQuery: String = "") {
        if workspace.activeProject?.id == projectId,
           workspace.activeProject?.activeWorktree?.id == worktreeId {
            openFile(path)
            if !searchQuery.isEmpty {
                searchHighlightQuery = searchQuery
                computeSearchHighlightRanges(query: searchQuery)
            }
            return
        }

        saveTabsToWorktree()
        pendingOpenFile = PendingOpenFile(path: path, projectId: projectId, worktreeId: worktreeId, searchQuery: searchQuery)
        workspace.setActiveWorktree(projectId: projectId, worktreeId: worktreeId)
    }

    private func computeSearchHighlightRanges(query: String) {
        guard !query.isEmpty else {
            searchHighlightRanges = []
            return
        }
        let content = editorContent as NSString
        var ranges: [NSRange] = []
        var searchStart = 0
        while searchStart < content.length {
            let range = content.range(of: query, options: .caseInsensitive, range: NSRange(location: searchStart, length: content.length - searchStart))
            if range.location == NSNotFound { break }
            ranges.append(range)
            searchStart = range.location + range.length
        }
        searchHighlightRanges = ranges
        searchHighlightIndex = 0
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

    public var showHTMLPreview: Bool {
        get { activeTabId.flatMap { htmlPreviewTabs.contains($0) } ?? false }
        set {
            if let id = activeTabId {
                if newValue { htmlPreviewTabs.insert(id) }
                else { htmlPreviewTabs.remove(id) }
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
                    self.splitVM?.saveToWorktree(&self.workspace.projects[projIdx].worktrees[prevWtIdx])
                     self.workspace.projects[projIdx].worktrees[prevWtIdx].fileTabs = self.tabs
                     self.workspace.projects[projIdx].worktrees[prevWtIdx].terminalTabs = self.terminal.tabs
                     self.workspace.projects[projIdx].worktrees[prevWtIdx].activeTabId = self.activeTabId
                     self.workspace.projects[projIdx].worktrees[prevWtIdx].browserURLs = self.browserURLs
                     self.workspace.projects[projIdx].worktrees[prevWtIdx].browserTitles = self.browserTitles
                     self.workspace.saveProjects()
                }

                    if let activeProject = project, let worktree = activeProject.activeWorktree {
                    previousWorktreeId = worktree.id
                    self.loadTabs(from: worktree)
                    if let pending = self.pendingOpenFile {
                        self.pendingOpenFile = nil
                        self.openFile(pending.path)
                        if !pending.searchQuery.isEmpty {
                            self.searchHighlightQuery = pending.searchQuery
                            self.computeSearchHighlightRanges(query: pending.searchQuery)
                        }
                    }
                } else {
                    self.tabs = []
                    self.terminal.tabs = []
                    self.activeTabId = nil
                }
            }
            .store(in: &cancellables)
    }

    private func loadTabs(from worktree: Worktree) {
        splitVM?.loadFromWorktree(worktree)
        tabs = worktree.fileTabs
        terminal.tabs = worktree.terminalTabs
        terminal.setWorktreeMapping(tabs: worktree.terminalTabs, worktreeId: worktree.id)
        terminal.refreshSessionsForRestoredTabs(workspace: workspace)
        activeTabId = worktree.activeTabId
        browserURLs = worktree.browserURLs
        browserTitles = worktree.browserTitles

        if tabs.isEmpty && terminal.tabs.isEmpty,
           let tabType = TabType(rawValue: settings.defaultTabOnProjectOpen) {
            createTerminalTab(type: tabType)
            saveTabsToWorktree()
        }

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
                guard tab.id == self.autoSaveTabId else { return }
                let original = self.fileContents[tab.id] ?? ""
                if content != original {
                    self.saveCurrentFile()
                }
                self.autoSaveTabId = nil
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

        splitVM?.saveToWorktree(&workspace.projects[projIdx].worktrees[wtIdx])
        workspace.projects[projIdx].worktrees[wtIdx].fileTabs = tabs
        workspace.projects[projIdx].worktrees[wtIdx].terminalTabs = terminal.tabs
        workspace.projects[projIdx].worktrees[wtIdx].activeTabId = activeTabId
        workspace.projects[projIdx].worktrees[wtIdx].browserURLs = browserURLs
        workspace.projects[projIdx].worktrees[wtIdx].browserTitles = browserTitles
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
        NSApp.activate(ignoringOtherApps: true)
        NSApp.runModal(for: panel)
        if panel.url != nil, let url = panel.url {
            openFile(url.path)
        }
        panel.close()
    }

    public func openFile(_ path: String) {
        searchHighlightQuery = ""
        searchHighlightRanges = []
        searchHighlightIndex = 0
        showInFileSearch = false
        inFileSearchQuery = ""
        inFileSearchResults = []
        inFileSearchCurrentIndex = 0
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

    @discardableResult
    public func openFileInNewTab(_ path: String) -> Tab {
        let name = URL(fileURLWithPath: path).lastPathComponent
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()

        if isImageExtension(ext) {
            let tab = Tab(path: path, name: name, language: "Image", type: .image)
            tabs.append(tab)
            saveTabsToWorktree()
            return tab
        }

        if isPDFExtension(ext) {
            let tab = Tab(path: path, name: name, language: "PDF", type: .pdf)
            tabs.append(tab)
            saveTabsToWorktree()
            return tab
        }

        let language = languageForExtension(ext)
        let content = fs.readFile(path: path)

        let tab = Tab(path: path, name: name, language: language, type: .file)
        tabs.append(tab)
        fileContents[tab.id] = content
        detectLanguage(from: name)
        saveTabsToWorktree()
        return tab
    }

    public func openFileFromTree(_ entry: FileEntry) {
        guard !entry.isDirectory else { return }
        openFile(entry.path)
    }

    // MARK: - Browser Tabs

    public func openURL(_ urlString: String) {
        let normalized = normalizeURL(urlString)

        let existingTab = tabs.first { tab in
            guard tab.type == .browser else { return false }
            let tabURL = browserURLs[tab.id] ?? tab.url ?? ""
            let normalizedTabURL = normalizeURL(tabURL)
            return normalizedTabURL == normalized
        }

        if let existing = existingTab {
            activateTab(existing.id)
            return
        }
        let displayName = URL(string: normalized)?.host ?? normalized
        let tab = Tab(
            name: displayName,
            type: .browser,
            url: normalized
        )
        tabs.append(tab)
        activeTabId = tab.id
        browserURLs[tab.id] = normalized
        browserTitles[tab.id] = ""
        saveTabsToWorktree()
    }

    public func updateBrowserURL(tabId: String, url: String) {
        let normalizedNew = normalizeURL(url)
        guard browserURLs[tabId] != normalizedNew else {
            return
        }
        browserURLs[tabId] = normalizedNew
        if let idx = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[idx].url = normalizedNew
        }
    }

    public func updateBrowserTitle(tabId: String, title: String) {
        browserTitles[tabId] = title
        if !title.isEmpty, let idx = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[idx].name = title
            saveTabsToWorktree()
        }
    }

    private func normalizeURL(_ urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        return "http://" + trimmed
    }

    // MARK: - Diagram Tab

    public func openDiagramTab(configID: String, schema: String, databaseName: String) {
        let name = "ER - \(databaseName):\(schema)"
        if let existing = tabs.first(where: { $0.type == .diagram && $0.queryTableSchema == schema && $0.queryConnectionId == configID }) {
            activateTab(existing.id)
            return
        }
        let tab = Tab(
            name: name,
            type: .diagram,
            queryConnectionId: configID,
            queryTableSchema: schema
        )
        tabs.append(tab)
        activeTabId = tab.id
        saveTabsToWorktree()
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

    public func addQueryHistory(forTab tabId: String, sql: String, connectionName: String, duration: TimeInterval, rowCount: Int, isError: Bool) {
        let item = QueryHistoryItem(
            id: UUID(),
            sql: sql,
            timestamp: Date(),
            connectionName: connectionName,
            duration: duration,
            rowCount: rowCount,
            isError: isError
        )
        var history = queryHistory[tabId] ?? []
        history.insert(item, at: 0)
        if history.count > 200 {
            history = Array(history.prefix(200))
        }
        queryHistory[tabId] = history
    }

    public func activateTab(_ id: String) {
        searchHighlightQuery = ""
        searchHighlightRanges = []
        searchHighlightIndex = 0
        showInFileSearch = false
        inFileSearchQuery = ""
        inFileSearchResults = []
        inFileSearchCurrentIndex = 0
        autoSaveTimer?.cancel()
        autoSaveTabId = nil
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
            } else if tab.type == .browser {
                editorContent = ""
                currentLanguage = "Browser"
            } else if tab.type == .diagram {
                editorContent = ""
                currentLanguage = "ER Diagram"
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
            if tab.type == .file && !tab.path.isEmpty {
                autoSaveTabId = tab.id
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
            queryHistory.removeValue(forKey: id)
            browserURLs.removeValue(forKey: id)
            browserTitles.removeValue(forKey: id)
            restApiTabStates.removeValue(forKey: id)

            if activeTabId == id {
                let newActiveId = tabs.last?.id ?? terminal.tabs.last?.id
                activeTabId = newActiveId
                if let newId = newActiveId, tabs.contains(where: { $0.id == newId }) {
                    let content = fileContents[newId] ?? (tabs.first { $0.id == newId }?.path.isEmpty == false ? fs.readFile(path: tabs.first { $0.id == newId }!.path) : "")
                    editorContent = content
                    if let tab = tabs.first(where: { $0.id == newId }), tab.type == .file && !tab.path.isEmpty {
                        autoSaveTabId = tab.id
                    }
                }
            }
            saveTabsToWorktree()
        } else if terminal.tabs.firstIndex(where: { $0.id == id }) != nil {
            splitVM?.destroyTerminalSessions(for: id)
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
            
        }
    }

    public func saveCurrentFileAs() {
        guard let tab = currentTab, tab.type == .file else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = tab.name
        NSApp.activate(ignoringOtherApps: true)
        NSApp.runModal(for: panel)
        if panel.url != nil, let url = panel.url {
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
                
            }
        }
        panel.close()
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
        guard source < tabs.count, source != destination else { return }
        let tab = tabs.remove(at: source)
        let insertAt = max(0, min(destination, tabs.count))
        tabs.insert(tab, at: insertAt)
        saveTabsToWorktree()
    }
}