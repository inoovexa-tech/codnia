import Foundation

struct BrowserConsoleEntry: Identifiable, Equatable {
    let id: UUID
    let level: Level
    let message: String
    let timestamp: Date
    let stack: String?
    let elementInfo: ElementInfo?

    enum Level: String, Equatable {
        case log
        case info
        case warn
        case error
    }

    struct ElementInfo: Equatable {
        let tag: String
        let nodeId: String
        let classes: String
    }

    init(level: Level, message: String, timestamp: Date = Date(), stack: String? = nil, elementInfo: ElementInfo? = nil) {
        self.id = UUID()
        self.level = level
        self.message = message
        self.timestamp = timestamp
        self.stack = stack
        self.elementInfo = elementInfo
    }

    var hasElementLink: Bool {
        elementInfo != nil || (stack?.contains(".html:") ?? false) || (stack?.contains(".js:") ?? false)
    }
}
