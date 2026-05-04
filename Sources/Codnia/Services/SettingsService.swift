import Foundation
import Combine

public final class SettingsService: ObservableObject {
    @Published public var fontSize: Double = 13
    @Published public var terminalFontSize: Double = 13
    @Published public var terminalScrollback: Int = 10000
    @Published public var editorTheme: String = "dark-pure"
    @Published public var autoSave: Bool = false
    @Published public var showLineNumbers: Bool = true
    @Published public var tabSize: Int = 4
    @Published public var wordWrap: Bool = true

    private let defaults = UserDefaults.standard
    private let prefix = "codnia.settings."

    public init() {
        load()
    }

    public func load() {
        fontSize = defaults.double(forKey: prefix + "fontSize")
        if fontSize == 0 { fontSize = 13 }
        terminalFontSize = defaults.double(forKey: prefix + "terminalFontSize")
        if terminalFontSize == 0 { terminalFontSize = 13 }
        terminalScrollback = defaults.integer(forKey: prefix + "terminalScrollback")
        if terminalScrollback == 0 { terminalScrollback = 10000 }
        editorTheme = defaults.string(forKey: prefix + "editorTheme") ?? "dark-pure"
        autoSave = defaults.bool(forKey: prefix + "autoSave")
        showLineNumbers = defaults.object(forKey: prefix + "showLineNumbers") as? Bool ?? true
        tabSize = defaults.integer(forKey: prefix + "tabSize")
        if tabSize == 0 { tabSize = 4 }
        wordWrap = defaults.bool(forKey: prefix + "wordWrap")
    }

    public func save() {
        defaults.set(fontSize, forKey: prefix + "fontSize")
        defaults.set(terminalFontSize, forKey: prefix + "terminalFontSize")
        defaults.set(terminalScrollback, forKey: prefix + "terminalScrollback")
        defaults.set(editorTheme, forKey: prefix + "editorTheme")
        defaults.set(autoSave, forKey: prefix + "autoSave")
        defaults.set(showLineNumbers, forKey: prefix + "showLineNumbers")
        defaults.set(tabSize, forKey: prefix + "tabSize")
        defaults.set(wordWrap, forKey: prefix + "wordWrap")
    }
}
