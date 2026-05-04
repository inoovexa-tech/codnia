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
    private var fileContents: [String: String] = [:n] // tabId -> original content

    public init(workspace: WorkspaceService, settings: SettingsService, terminal: TerminalViewModel) {
        self.workspace = workspace
        self.settings = settings
        self.terminal = terminal
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
            return
        }

        let tab = Tab(path: path, name: name, language: language, type: .file)
        tabs.append(tab)
        activeTabId = tab.id
        editorContent = content
        currentLanguage = language
        fileContents[tab.id] = content
        detectLanguage(from: name)
    }

    public func openFileFromTree(_ entry: FileEntry) {
        guard !entry.isDirectory else { return }
        openFile(entry.path)
    }

    public func activateTab(_ id: String) {
        activeTabId = id
        if let tab = tabs.first(where: { $0.id == id }) {
            editorContent = fs.readFile(path: tab.path)
            currentLanguage = tab.language
            detectLanguage(from: tab.name)
        }
    }

    public func closeTab(_ id: String) {
        if let tab = tabs.first(where: { $0.id == id }) {
            tabs.removeAll { $0.id == id }
            fileContents.removeValue(forKey: id)

            if activeTabId == id {
                activeTabId = tabs.last?.id ?? terminal.tabs.last?.id
            }
        } else if let tab = terminal.tabs.first(where: { $0.id == id }) {
            terminal.closeTab(tab)
            if activeTabId == id {
                activeTabId = allTabs.last?.id
            }
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
        do {
            try fs.writeFile(path: tab.path, content: editorContent)
            fileContents[tab.id] = editorContent
            if let idx = tabs.firstIndex(where: { $0.id == tab.id }) {
                tabs[idx].isModified = false
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
                }
            } catch {
                print("Save As failed: \(error)")
            }
        }
    }

    public func createTerminalTab(type: TabType = .terminal) {
        terminal.createTerminalTab(type: type)
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
}
