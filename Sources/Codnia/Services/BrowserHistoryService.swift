import Foundation
import Combine

@MainActor
public final class BrowserHistoryService: ObservableObject {
    @Published public private(set) var entries: [BrowserHistoryEntry] = []
    @Published public var searchText: String = ""

    private let fs = FileSystemService.shared
    private var workspacePath: String = ""
    private let fileName = "history.json"
    private let maxEntries = 5000

    public init() {}

    public func load(from path: String) {
        workspacePath = path
        let url = (path as NSString).appendingPathComponent(".codnia/browser/\(fileName)")
        guard FileManager.default.fileExists(atPath: url),
              let data = try? Data(contentsOf: URL(fileURLWithPath: url)),
              let decoded = try? JSONDecoder().decode([BrowserHistoryEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded
    }

    public func save() {
        guard !workspacePath.isEmpty else { return }
        let dir = (workspacePath as NSString).appendingPathComponent(".codnia/browser")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let url = (dir as NSString).appendingPathComponent(fileName)
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: URL(fileURLWithPath: url), options: .atomic)
        }
    }

    public func recordVisit(url: String, title: String) {
        guard !url.isEmpty, url != "about:blank" else { return }
        if let idx = entries.firstIndex(where: { $0.url == url }) {
            entries[idx].visitedAt = Date()
            entries[idx].visitCount += 1
            entries[idx].title = title.isEmpty ? entries[idx].title : title
        } else {
            entries.insert(BrowserHistoryEntry(url: url, title: title), at: 0)
        }
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    public func remove(_ entry: BrowserHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    public func remove(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    public func clearAll() {
        entries = []
        save()
    }

    public var filtered: [BrowserHistoryEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.url.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var groupedByDay: [(day: String, items: [BrowserHistoryEntry])] {
        let groups = Dictionary(grouping: filtered, by: { $0.dayKey })
        return groups.keys.sorted(by: >).map { key in
            let dayLabel: String = {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                guard let date = fmt.date(from: key) else { return key }
                if Calendar.current.isDateInToday(date) { return "Today" }
                if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
                let display = DateFormatter()
                display.dateFormat = "EEEE, MMM d"
                return display.string(from: date)
            }()
            return (dayLabel, groups[key]?.sorted { $0.visitedAt > $1.visitedAt } ?? [])
        }
    }

    public func matches(url: String) -> BrowserHistoryEntry? {
        entries.first { $0.url == url }
    }
}
