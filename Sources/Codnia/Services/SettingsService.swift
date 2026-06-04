import Foundation
import Combine

public final class SettingsService: ObservableObject {
    @Published public var fontSize: Double = 13
    @Published public var terminalFontSize: Double = 13
    @Published public var terminalScrollback: Int = 10000
    @Published public var defaultTabOnProjectOpen: String = "terminal"
    @Published public var editorTheme: String = "dark-pure"
    @Published public var autoSave: Bool = false
    @Published public var tabSize: Int = 4
    @Published public var wordWrap: Bool = true
    @Published public var activityBarWidth: CGFloat = 320
    @Published public var leftSidebarWidth: CGFloat = 220
    @Published public var leftSidebarExpanded: Bool = true

    @Published public var browserEnabled: Bool = true
    @Published public var browserAutoRedirect: Bool = false
    @Published public var browserInterceptLocalhost: Bool = true
    @Published public var browserInterceptPrivateIPs: Bool = true

    @Published public var leftBrowserWidth: CGFloat = 350
    @Published public var rightBrowserWidth: CGFloat = 350

    @Published public var browserDefaultURL: String = ""
    @Published public var browserDefaultLocation: String = "tab"

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
        editorTheme = defaults.string(forKey: prefix + "editorTheme") ?? "Codnia Dark"
        autoSave = defaults.bool(forKey: prefix + "autoSave")
        tabSize = defaults.integer(forKey: prefix + "tabSize")
        if tabSize == 0 { tabSize = 4 }
        wordWrap = defaults.bool(forKey: prefix + "wordWrap")
        activityBarWidth = CGFloat(defaults.double(forKey: prefix + "activityBarWidth"))
        if activityBarWidth == 0 { activityBarWidth = 320 }
        leftSidebarWidth = CGFloat(defaults.double(forKey: prefix + "leftSidebarWidth"))
        if leftSidebarWidth == 0 { leftSidebarWidth = 220 }
        leftSidebarExpanded = defaults.object(forKey: prefix + "leftSidebarExpanded") as? Bool ?? true

        browserEnabled = defaults.object(forKey: prefix + "browserEnabled") as? Bool ?? true
        browserAutoRedirect = defaults.object(forKey: prefix + "browserAutoRedirect") as? Bool ?? false
        browserInterceptLocalhost = defaults.object(forKey: prefix + "browserInterceptLocalhost") as? Bool ?? true
        browserInterceptPrivateIPs = defaults.object(forKey: prefix + "browserInterceptPrivateIPs") as? Bool ?? true

        leftBrowserWidth = CGFloat(defaults.double(forKey: prefix + "leftBrowserWidth"))
        if leftBrowserWidth == 0 { leftBrowserWidth = 350 }
        rightBrowserWidth = CGFloat(defaults.double(forKey: prefix + "rightBrowserWidth"))
        if rightBrowserWidth == 0 { rightBrowserWidth = 350 }

        browserDefaultURL = defaults.string(forKey: prefix + "browserDefaultURL") ?? ""
        browserDefaultLocation = defaults.string(forKey: prefix + "browserDefaultLocation") ?? "tab"

        setupAutosave()
    }

    private func setupAutosave() {
        let group1 = Publishers.MergeMany([
            $fontSize.map { _ in () }.eraseToAnyPublisher(),
            $terminalFontSize.map { _ in () }.eraseToAnyPublisher(),
            $defaultTabOnProjectOpen.map { _ in () }.eraseToAnyPublisher(),
            $editorTheme.map { _ in () }.eraseToAnyPublisher(),
            $autoSave.map { _ in () }.eraseToAnyPublisher(),
            $tabSize.map { _ in () }.eraseToAnyPublisher(),
            $wordWrap.map { _ in () }.eraseToAnyPublisher(),
        ])
        let group2 = Publishers.MergeMany([
            $activityBarWidth.map { _ in () }.eraseToAnyPublisher(),
            $leftSidebarWidth.map { _ in () }.eraseToAnyPublisher(),
            $leftSidebarExpanded.map { _ in () }.eraseToAnyPublisher(),
            $browserEnabled.map { _ in () }.eraseToAnyPublisher(),
            $browserAutoRedirect.map { _ in () }.eraseToAnyPublisher(),
            $browserInterceptLocalhost.map { _ in () }.eraseToAnyPublisher(),
            $browserInterceptPrivateIPs.map { _ in () }.eraseToAnyPublisher(),
            $leftBrowserWidth.map { _ in () }.eraseToAnyPublisher(),
        ])
        let group3 = Publishers.MergeMany([
            $rightBrowserWidth.map { _ in () }.eraseToAnyPublisher(),
            $browserDefaultURL.map { _ in () }.eraseToAnyPublisher(),
            $browserDefaultLocation.map { _ in () }.eraseToAnyPublisher(),
        ])
        group1
            .merge(with: group2, group3)
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
        defaults.set(tabSize, forKey: prefix + "tabSize")
        defaults.set(wordWrap, forKey: prefix + "wordWrap")
        defaults.set(Double(activityBarWidth), forKey: prefix + "activityBarWidth")
        defaults.set(Double(leftSidebarWidth), forKey: prefix + "leftSidebarWidth")
        defaults.set(leftSidebarExpanded, forKey: prefix + "leftSidebarExpanded")
        defaults.set(browserEnabled, forKey: prefix + "browserEnabled")
        defaults.set(browserAutoRedirect, forKey: prefix + "browserAutoRedirect")
        defaults.set(browserInterceptLocalhost, forKey: prefix + "browserInterceptLocalhost")
        defaults.set(browserInterceptPrivateIPs, forKey: prefix + "browserInterceptPrivateIPs")
        defaults.set(Double(leftBrowserWidth), forKey: prefix + "leftBrowserWidth")
        defaults.set(Double(rightBrowserWidth), forKey: prefix + "rightBrowserWidth")
        defaults.set(browserDefaultURL, forKey: prefix + "browserDefaultURL")
        defaults.set(browserDefaultLocation, forKey: prefix + "browserDefaultLocation")
    }
}
