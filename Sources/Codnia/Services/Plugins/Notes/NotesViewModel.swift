import Foundation
import SwiftUI

public enum NoteSortOrder: String, CaseIterable {
    case name = "Name"
    case modifiedAt = "Last Modified"
    case createdAt = "Created"
}

public struct NoteEntry: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public var isFavorite: Bool = false
    public var tags: [String] = []
    public var createdAt: Date?
    public var modifiedAt: Date?
    public var frontmatterTitle: String?
    public var preview: String?

    public init(id: String = UUID().uuidString, name: String, path: String, isDirectory: Bool = false) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
    }

    public static func == (lhs: NoteEntry, rhs: NoteEntry) -> Bool {
        lhs.id == rhs.id
    }
}

public struct NoteTemplate: Identifiable, Codable {
    public let id: String
    public let name: String
    public let content: String
    public let icon: String

    public init(id: String = UUID().uuidString, name: String, content: String, icon: String = "doc.text") {
        self.id = id
        self.name = name
        self.content = content
        self.icon = icon
    }
}

@MainActor
public final class NotesViewModel: ObservableObject {
    @Published public var entries: [NoteEntry] = []
    @Published public var favoriteEntries: [NoteEntry] = []
    @Published public var recentEntries: [NoteEntry] = []
    @Published public var searchText: String = ""
    @Published public var selectedTags: Set<String> = []
    @Published public var allTags: [String] = []
    @Published public var templates: [NoteTemplate] = []
    @Published public var isLoading: Bool = false
    @Published public var showNewNoteSheet: Bool = false
    @Published public var showDeleteConfirmation: Bool = false
    @Published public var noteToDelete: NoteEntry?
    @Published public var showTemplatePicker: Bool = false
    @Published public var expandedDirectories: Set<String> = []
    @Published public var sortOrder: NoteSortOrder = .name
    @Published public var editingNoteId: String?
    @Published public var editingNoteText: String = ""

    private let fileSystem = FileSystemService.shared
    private var workspacePath: String = ""
    private let favoritesKey = "notes_favorites"
    private let recentsKey = "notes_recents"
    private let templatesKey = "notes_templates"
    private let expandedDirsKey = "notes_expanded_dirs"
    private let maxRecentNotes = 10

    public init() {
        loadTemplates()
        expandedDirectories = loadExpandedDirectories()
    }

    public func loadNotes(from path: String) {
        guard !path.isEmpty else {
            entries = []
            favoriteEntries = []
            recentEntries = []
            allTags = []
            workspacePath = ""
            return
        }
        workspacePath = path
        isLoading = true
        entries = []
        favoriteEntries = []
        recentEntries = []
        allTags = []

        let notesDir = (path as NSString).appendingPathComponent(".codnia/notes")
        let mdExtensions = ["md", "markdown"]
        var allNotes: [NoteEntry] = []
        var foundTags: Set<String> = []

        findMarkdownFiles(in: notesDir, extensions: mdExtensions, into: &allNotes, foundTags: &foundTags)

        for i in allNotes.indices {
            allNotes[i].isFavorite = isFavorite(path: allNotes[i].path)
            allNotes[i].tags = extractTags(from: allNotes[i].path)
            allNotes[i].frontmatterTitle = extractFrontmatterTitle(from: allNotes[i].path)
            allNotes[i].createdAt = getFileCreationDate(path: allNotes[i].path)
            allNotes[i].modifiedAt = getFileModificationDate(path: allNotes[i].path)
            allNotes[i].preview = extractPreview(from: allNotes[i].path)
        }

        let favorites = allNotes.filter { $0.isFavorite }

        entries = allNotes
        favoriteEntries = favorites
        recentEntries = allNotes
            .filter { $0.modifiedAt != nil }
            .sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
            .prefix(maxRecentNotes)
            .map { $0 }
        allTags = Array(foundTags).sorted()

        isLoading = false
    }

    private func findMarkdownFiles(in path: String, extensions: [String], into results: inout [NoteEntry], foundTags: inout Set<String>) {
        let dirContents = fileSystem.listDirectory(path: path)

        for entry in dirContents {
            if entry.isDirectory {
                findMarkdownFiles(in: entry.path, extensions: extensions, into: &results, foundTags: &foundTags)
            } else {
                let ext = (entry.name as NSString).pathExtension.lowercased()
                if extensions.contains(ext) {
                    results.append(NoteEntry(
                        name: entry.name,
                        path: entry.path
                    ))
                }
            }
        }
    }

    public var filteredEntries: [NoteEntry] {
        var result = entries

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.frontmatterTitle?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        if !selectedTags.isEmpty {
            result = result.filter { entry in
                let entryTags = extractTags(from: entry.path)
                return !selectedTags.isDisjoint(with: Set(entryTags))
            }
        }

        switch sortOrder {
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .modifiedAt:
            result.sort { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
        case .createdAt:
            result.sort { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        }

        return result
    }

    public var rootNotesPath: String {
        (workspacePath as NSString).appendingPathComponent(".codnia/notes")
    }

    public var filteredRootStructure: NoteDirectory {
        buildTree(from: filteredEntries, rootPath: rootNotesPath)
    }

    public func buildTree(from notes: [NoteEntry], rootPath: String) -> NoteDirectory {
        var notesByDir: [String: [NoteEntry]] = [:]
        var childDirsByParent: [String: [String]] = [:]
        var dirNames: [String: String] = [:]

        for note in notes {
            let dir = (note.path as NSString).deletingLastPathComponent
            notesByDir[dir, default: []].append(note)
        }

        for dirPath in notesByDir.keys where dirPath != rootPath {
            let parent = (dirPath as NSString).deletingLastPathComponent
            childDirsByParent[parent, default: []].append(dirPath)
            dirNames[dirPath] = (dirPath as NSString).lastPathComponent
        }

        func buildNode(path: String) -> NoteDirectory {
            let name = dirNames[path] ?? (path as NSString).lastPathComponent
            let notes = notesByDir[path] ?? []
            let subdirs = (childDirsByParent[path] ?? [])
                .map { buildNode(path: $0) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return NoteDirectory(
                name: name,
                path: path,
                directories: subdirs,
                notes: notes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            )
        }

        return buildNode(path: rootPath)
    }

    public func createNote(name: String, inDirectory directory: String, content: String = "") throws -> String {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { throw NotesError.emptyFileName }

        var fileName = cleanName
        if !(fileName.lowercased().hasSuffix(".md") || fileName.lowercased().hasSuffix(".markdown")) {
            fileName += ".md"
        }

        let dirPath = resolveNotesSubpath(directory)
        try fileSystem.createDirectory(path: dirPath)

        let filePath = (dirPath as NSString).appendingPathComponent(fileName)

        if fileSystem.fileExists(atPath: filePath) {
            throw NotesError.fileAlreadyExists
        }

        let initialContent = content.isEmpty ? generateDefaultContent(title: cleanName.replacingOccurrences(of: ".md", with: "").replacingOccurrences(of: ".markdown", with: "")) : content

        try fileSystem.writeFile(path: filePath, content: initialContent)
        refreshNotes()
        addToRecent(path: filePath)

        return filePath
    }

    private func generateDefaultContent(title: String) -> String {
        let date = ISO8601DateFormatter().string(from: Date())
        return """
        ---
        title: "\(title)"
        created: "\(date)"
        tags: []
        ---

        # \(title)


        """
    }

    public func createNoteFromTemplate(name: String, inDirectory directory: String, templateId: String) throws -> String {
        guard let template = templates.first(where: { $0.id == templateId }) else {
            throw NotesError.templateNotFound
        }

        var content = template.content
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        let title = cleanName.replacingOccurrences(of: ".md", with: "").replacingOccurrences(of: ".markdown", with: "")

        content = content.replacingOccurrences(of: "{{title}}", with: title)
        content = content.replacingOccurrences(of: "{{date}}", with: ISO8601DateFormatter().string(from: Date()))

        return try createNote(name: name, inDirectory: directory, content: content)
    }

    public func deleteNote(_ entry: NoteEntry) throws {
        try fileSystem.delete(path: entry.path)
        removeFromFavorites(path: entry.path)
        removeFromRecent(path: entry.path)
        refreshNotes()
    }

    public func renameNote(_ entry: NoteEntry, to newName: String) throws {
        let cleanName = newName.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { throw NotesError.emptyFileName }

        var fileName = cleanName
        if !fileName.lowercased().hasSuffix(".md") && !fileName.lowercased().hasSuffix(".markdown") {
            fileName += ".md"
        }

        let directory = (entry.path as NSString).deletingLastPathComponent
        let newPath = (directory as NSString).appendingPathComponent(fileName)

        if fileSystem.fileExists(atPath: newPath) && newPath != entry.path {
            throw NotesError.fileAlreadyExists
        }

        try fileSystem.rename(oldPath: entry.path, newPath: newPath)
        updateFavoritePath(from: entry.path, to: newPath)
        updateRecentPath(from: entry.path, to: newPath)
        refreshNotes()
    }

    public func moveNote(_ entry: NoteEntry, toDirectory newDirectory: String) throws {
        let fileName = (entry.path as NSString).lastPathComponent
        let newPath = (newDirectory as NSString).appendingPathComponent(fileName)

        if fileSystem.fileExists(atPath: newPath) {
            throw NotesError.fileAlreadyExists
        }

        try fileSystem.rename(oldPath: entry.path, newPath: newPath)
        updateFavoritePath(from: entry.path, to: newPath)
        updateRecentPath(from: entry.path, to: newPath)
        refreshNotes()
    }

    public func duplicateNote(_ entry: NoteEntry) throws -> String {
        let newPath = try fileSystem.duplicate(path: entry.path)
        refreshNotes()
        addToRecent(path: newPath)
        return newPath
    }

    public func openNote(_ entry: NoteEntry) -> String {
        addToRecent(path: entry.path)
        return entry.path
    }

    public func toggleFavorite(_ entry: NoteEntry) {
        if isFavorite(path: entry.path) {
            removeFromFavorites(path: entry.path)
        } else {
            addToFavorites(path: entry.path)
        }
        refreshNotes()
    }

    private func isFavorite(path: String) -> Bool {
        UserDefaults.standard.stringArray(forKey: favoritesKey)?.contains(path) ?? false
    }

    private func addToFavorites(path: String) {
        var favorites = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        if !favorites.contains(path) {
            favorites.append(path)
            UserDefaults.standard.set(favorites, forKey: favoritesKey)
        }
    }

    private func removeFromFavorites(path: String) {
        var favorites = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        favorites.removeAll { $0 == path }
        UserDefaults.standard.set(favorites, forKey: favoritesKey)
    }

    private func updateFavoritePath(from oldPath: String, to newPath: String) {
        var favorites = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        if let index = favorites.firstIndex(of: oldPath) {
            favorites[index] = newPath
            UserDefaults.standard.set(favorites, forKey: favoritesKey)
        }
    }

    private func addToRecent(path: String) {
        var recents = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
        recents.removeAll { $0 == path }
        recents.insert(path, at: 0)
        if recents.count > maxRecentNotes {
            recents = Array(recents.prefix(maxRecentNotes))
        }
        UserDefaults.standard.set(recents, forKey: recentsKey)
    }

    private func removeFromRecent(path: String) {
        var recents = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
        recents.removeAll { $0 == path }
        UserDefaults.standard.set(recents, forKey: recentsKey)
    }

    private func updateRecentPath(from oldPath: String, to newPath: String) {
        var recents = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
        if let index = recents.firstIndex(of: oldPath) {
            recents[index] = newPath
            UserDefaults.standard.set(recents, forKey: recentsKey)
        }
    }

    public func saveTemplate(_ template: NoteTemplate) {
        var allTemplates = templates
        if let index = allTemplates.firstIndex(where: { $0.id == template.id }) {
            allTemplates[index] = template
        } else {
            allTemplates.append(template)
        }
        templates = allTemplates
        saveTemplatesToDisk()
    }

    public func deleteTemplate(_ template: NoteTemplate) {
        templates.removeAll { $0.id == template.id }
        saveTemplatesToDisk()
    }

    private func saveTemplatesToDisk() {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: templatesKey)
        }
    }

    private func loadTemplates() {
        if let data = UserDefaults.standard.data(forKey: templatesKey),
           let savedTemplates = try? JSONDecoder().decode([NoteTemplate].self, from: data) {
            templates = savedTemplates
        } else {
            templates = [
                NoteTemplate(name: "Meeting Notes", content: "---\ntitle: \"{{title}}\"\ndate: \"{{date}}\"\ntags: [meeting]\n---\n\n# {{title}}\n\n## Attendees\n- \n\n## Agenda\n1. \n\n## Notes\n\n\n## Action Items\n- [ ] \n", icon: "person.3"),
                NoteTemplate(name: "Task List", content: "---\ntitle: \"{{title}}\"\ndate: \"{{date}}\"\ntags: [tasks]\n---\n\n# {{title}}\n\n## To Do\n- [ ] \n\n## In Progress\n- [ ] \n\n## Done\n- [x] \n", icon: "checklist"),
                NoteTemplate(name: "Daily Journal", content: "---\ntitle: \"{{title}}\"\ndate: \"{{date}}\"\ntags: [journal]\n---\n\n# {{title}}\n\n## Morning\n\n## Afternoon\n\n## Evening\n\n## Gratitude\n- \n", icon: "book"),
                NoteTemplate(name: "Project Notes", content: "---\ntitle: \"{{title}}\"\ndate: \"{{date}}\"\ntags: [project]\n---\n\n# {{title}}\n\n## Overview\n\n## Goals\n\n## Progress\n\n## Blockers\n\n## Next Steps\n\n", icon: "folder")
            ]
        }
    }

    private func extractTags(from path: String) -> [String] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }

        if let frontmatter = extractFrontmatter(content) {
            if let tagsLine = frontmatter.components(separatedBy: "\n").first(where: { $0.lowercased().contains("tags:") }) {
                let tagsValue = tagsLine.replacingOccurrences(of: "tags:", with: "").trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                if !tagsValue.isEmpty {
                    return tagsValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }
            }
        }

        let hashTags = content.components(separatedBy: .newlines)
            .flatMap { line -> [String] in
                let matches = line.regexMatches(pattern: "#([a-zA-Z0-9_-]+)")
                return matches.map { String($0.dropFirst()) }
            }
        return Array(Set(hashTags))
    }

    private func extractFrontmatter(_ content: String) -> String? {
        guard content.hasPrefix("---") else { return nil }
        let lines = content.components(separatedBy: .newlines)
        var endIndex: Int?
        for (index, line) in lines.enumerated() {
            if index > 0 && line.hasPrefix("---") {
                endIndex = index
                break
            }
        }
        if let end = endIndex {
            return lines[1..<end].joined(separator: "\n")
        }
        return nil
    }

    private func extractFrontmatterTitle(from path: String) -> String? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8),
              let frontmatter = extractFrontmatter(content) else { return nil }

        if let titleLine = frontmatter.components(separatedBy: "\n").first(where: { $0.lowercased().hasPrefix("title:") }) {
            var title = titleLine.replacingOccurrences(of: "title:", with: "").trimmingCharacters(in: .whitespaces)
            title = title.replacingOccurrences(of: "\"", with: "")
            return title
        }
        return nil
    }

    private func getFileCreationDate(path: String) -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return attrs?[.creationDate] as? Date
    }

    private func getFileModificationDate(path: String) -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return attrs?[.modificationDate] as? Date
    }

    public func refreshNotes() {
        guard !workspacePath.isEmpty else { return }
        loadNotes(from: workspacePath)
    }

    public func createFolder(name: String, inDirectory directory: String) throws {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { throw NotesError.emptyFileName }

        let parentDir = resolveNotesSubpath(directory)
        let folderPath = (parentDir as NSString).appendingPathComponent(cleanName)

        if fileSystem.fileExists(atPath: folderPath) {
            throw NotesError.folderAlreadyExists
        }

        try fileSystem.createDirectory(path: folderPath)
        refreshNotes()
    }

    private func resolveNotesSubpath(_ subpath: String) -> String {
        let notesRoot = (workspacePath as NSString).appendingPathComponent(".codnia/notes")
        guard !subpath.isEmpty else { return notesRoot }
        return (notesRoot as NSString).appendingPathComponent(subpath)
    }

    public func toggleDirectoryExpanded(_ path: String) {
        if expandedDirectories.contains(path) {
            expandedDirectories.remove(path)
        } else {
            expandedDirectories.insert(path)
        }
        saveExpandedDirectories()
    }

    private func loadExpandedDirectories() -> Set<String> {
        UserDefaults.standard.stringArray(forKey: expandedDirsKey).map(Set.init) ?? []
    }

    private func saveExpandedDirectories() {
        UserDefaults.standard.set(Array(expandedDirectories), forKey: expandedDirsKey)
    }

    private func extractPreview(from path: String) -> String? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let body: String
        if content.hasPrefix("---") {
            if let fmEnd = content.range(of: "\n---\n") {
                body = String(content[fmEnd.upperBound...])
            } else {
                body = content
            }
        } else {
            body = content
        }
        for line in body.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                let maxLen = 80
                return trimmed.count > maxLen ? String(trimmed.prefix(maxLen)) + "…" : trimmed
            }
        }
        return nil
    }

    public func cancelEditing() {
        editingNoteId = nil
        editingNoteText = ""
    }

    public func startEditing(_ entry: NoteEntry) {
        let fileName = entry.name.replacingOccurrences(of: ".md", with: "").replacingOccurrences(of: ".markdown", with: "")
        editingNoteId = entry.id
        editingNoteText = fileName
    }
}

extension String {
    func regexMatches(pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(self.startIndex..., in: self)
        let matches = regex.matches(in: self, range: range)
        return matches.compactMap {
            guard let range = Range($0.range, in: self) else { return nil }
            return String(self[range])
        }
    }
}

public struct NoteDirectory: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let path: String
    public var directories: [NoteDirectory]
    public var notes: [NoteEntry]

    public init(name: String, path: String, directories: [NoteDirectory] = [], notes: [NoteEntry] = []) {
        self.id = path
        self.name = name
        self.path = path
        self.directories = directories
        self.notes = notes
    }

    public static func == (lhs: NoteDirectory, rhs: NoteDirectory) -> Bool {
        lhs.id == rhs.id
    }
}

public enum NotesError: Error, LocalizedError {
    case emptyFileName
    case fileAlreadyExists
    case folderAlreadyExists
    case templateNotFound
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyFileName:
            return "File name cannot be empty"
        case .fileAlreadyExists:
            return "A file with this name already exists"
        case .folderAlreadyExists:
            return "A folder with this name already exists"
        case .templateNotFound:
            return "Template not found"
        case .operationFailed(let message):
            return message
        }
    }
}