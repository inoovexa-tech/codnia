import Foundation
import Combine

public final class SettingsService: ObservableObject {
    @Published public var fontSize: Double = 13
    @Published public var terminalFontSize: Double = 13
    @Published public var terminalScrollback: Int = 10000
    @Published public var defaultTabOnProjectOpen: String = "terminal"
    @Published public var editorTheme: String = "dark-pure"
    @Published public var autoSave: Bool = false
    @Published public var showLineNumbers: Bool = true
    @Published public var tabSize: Int = 4
    @Published public var wordWrap: Bool = true
    @Published public var activityBarWidth: CGFloat = 320
    @Published public var leftSidebarWidth: CGFloat = 220
    @Published public var leftSidebarExpanded: Bool = true

    private let defaults = UserDefaults.standard
    private let prefix = "codnia.settings."
    private var cancellables = Set<AnyCancellable>()

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
        defaultTabOnProjectOpen = defaults.string(forKey: prefix + "defaultTabOnProjectOpen") ?? "terminal"
        editorTheme = defaults.string(forKey: prefix + "editorTheme") ?? "dark-pure"
        autoSave = defaults.bool(forKey: prefix + "autoSave")
        showLineNumbers = defaults.object(forKey: prefix + "showLineNumbers") as? Bool ?? true
        tabSize = defaults.integer(forKey: prefix + "tabSize")
        if tabSize == 0 { tabSize = 4 }
        wordWrap = defaults.bool(forKey: prefix + "wordWrap")
        activityBarWidth = CGFloat(defaults.double(forKey: prefix + "activityBarWidth"))
        if activityBarWidth == 0 { activityBarWidth = 320 }
        leftSidebarWidth = CGFloat(defaults.double(forKey: prefix + "leftSidebarWidth"))
        if leftSidebarWidth == 0 { leftSidebarWidth = 220 }
        leftSidebarExpanded = defaults.object(forKey: prefix + "leftSidebarExpanded") as? Bool ?? true

        setupAutosave()
    }

    private func setupAutosave() {
        let publishers = [
            $fontSize.map { _ in () }.eraseToAnyPublisher(),
            $terminalFontSize.map { _ in () }.eraseToAnyPublisher(),
            $defaultTabOnProjectOpen.map { _ in () }.eraseToAnyPublisher(),
            $editorTheme.map { _ in () }.eraseToAnyPublisher(),
            $autoSave.map { _ in () }.eraseToAnyPublisher(),
            $showLineNumbers.map { _ in () }.eraseToAnyPublisher(),
            $tabSize.map { _ in () }.eraseToAnyPublisher(),
            $wordWrap.map { _ in () }.eraseToAnyPublisher(),
            $activityBarWidth.map { _ in () }.eraseToAnyPublisher(),
            $leftSidebarWidth.map { _ in () }.eraseToAnyPublisher(),
            $leftSidebarExpanded.map { _ in () }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(publishers)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.save()
            }
            .store(in: &cancellables)
    }

    public func save() {
        defaults.set(fontSize, forKey: prefix + "fontSize")
        defaults.set(terminalFontSize, forKey: prefix + "terminalFontSize")
        defaults.set(terminalScrollback, forKey: prefix + "terminalScrollback")
        defaults.set(defaultTabOnProjectOpen, forKey: prefix + "defaultTabOnProjectOpen")
        defaults.set(editorTheme, forKey: prefix + "editorTheme")
        defaults.set(autoSave, forKey: prefix + "autoSave")
        defaults.set(showLineNumbers, forKey: prefix + "showLineNumbers")
        defaults.set(tabSize, forKey: prefix + "tabSize")
        defaults.set(wordWrap, forKey: prefix + "wordWrap")
        defaults.set(Double(activityBarWidth), forKey: prefix + "activityBarWidth")
        defaults.set(Double(leftSidebarWidth), forKey: prefix + "leftSidebarWidth")
        defaults.set(leftSidebarExpanded, forKey: prefix + "leftSidebarExpanded")
    }
}
