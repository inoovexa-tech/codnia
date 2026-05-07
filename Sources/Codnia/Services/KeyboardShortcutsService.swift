import Foundation
import Combine

@MainActor
public final class KeyboardShortcutsService: ObservableObject {
    @Published public var shortcuts: [String: String] = [:]
    private let defaults = UserDefaults.standard
    private let key = "codnia.keyboardShortcuts"

    public init() {
        load()
    }

    public func load() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            shortcuts = decoded
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
            "openFile": "Cmd+O",
            "save": "Cmd+S",
            "saveAs": "Cmd+Shift+S",
            "closeTab": "Cmd+W",
            "toggleSidebar": "Cmd+B",
            "toggleTerminal": "Cmd+`",
            "globalSearch": "Cmd+Shift+F",
            "settings": "Cmd+,",
            "nextTab": "Cmd+Tab",
            "previousTab": "Cmd+Shift+Tab",
        ]
    }
}
