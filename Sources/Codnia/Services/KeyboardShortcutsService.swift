import Foundation
import Combine

@MainActor
public final class KeyboardShortcutsService: ObservableObject {
    public static let shared = KeyboardShortcutsService()

    @Published public var shortcuts: [String: String] = [:]
    private let defaults = UserDefaults.standard
    private let key = "codnia.keyboardShortcuts"

    private init() {
        load()
    }

    public static func resetAll() {
        shared.shortcuts = shared.defaultShortcuts()
        shared.save()
    }

    public func load() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            shortcuts = defaultShortcuts().merging(decoded) { _, saved in saved }
        } else {
            shortcuts = defaultShortcuts()
        }
    }

    public func save() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            defaults.set(data, forKey: key)
        }
    }

    public func update(action: String, shortcut: String) {
        shortcuts[action] = shortcut
        save()
    }

    public func reset() {
        shortcuts = defaultShortcuts()
        save()
    }

    private func defaultShortcuts() -> [String: String] {
        [
            "newFile": "Cmd+N",
            "newTerminal": "Cmd+T",
            "openFile": "Cmd+O",
            "save": "Cmd+S",
            "saveAs": "Cmd+Shift+S",
            "closeTab": "Cmd+W",
            "toggleSidebar": "Cmd+B",
            "toggleTerminal": "Cmd+`",
            "globalSearch": "Cmd+Shift+F",
            "findInFile": "Cmd+F",
            "settings": "Cmd+,",
            "nextTab": "Cmd+Tab",
            "previousTab": "Cmd+Shift+Tab",
            "nextProject": "Cmd+Down",
            "previousProject": "Cmd+Up",
            "openOpenCode": "Cmd+Shift+O",
            "openClaude": "Cmd+Shift+C",
            "openCodex": "Cmd+Shift+X",
            "newSQLQuery": "Cmd+Shift+Q",
        ]
    }
}
