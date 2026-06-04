import Foundation
import Combine

@MainActor
public final class BrowserBookmarkService: ObservableObject {
    @Published public private(set) var bookmarks: [BrowserBookmark] = []
    @Published public var searchText: String = ""

    private let fs = FileSystemService.shared
    private var workspacePath: String = ""
    private let fileName = "bookmarks.json"

    public init() {}

    public func load(from path: String) {
        workspacePath = path
        let url = (path as NSString).appendingPathComponent(".codnia/browser/\(fileName)")
        guard FileManager.default.fileExists(atPath: url),
              let data = try? Data(contentsOf: URL(fileURLWithPath: url)),
              let decoded = try? JSONDecoder().decode([BrowserBookmark].self, from: data) else {
            bookmarks = []
            return
        }
        bookmarks = decoded
    }

    public func save() {
        guard !workspacePath.isEmpty else { return }
        let dir = (workspacePath as NSString).appendingPathComponent(".codnia/browser")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let url = (dir as NSString).appendingPathComponent(fileName)
        if let data = try? JSONEncoder().encode(bookmarks) {
            try? data.write(to: URL(fileURLWithPath: url), options: .atomic)
        }
    }

    public func isBookmarked(url: String) -> Bool {
        bookmarks.contains { $0.url == url }
    }

    public func toggle(title: String, url: String) {
        if let idx = bookmarks.firstIndex(where: { $0.url == url }) {
            bookmarks.remove(at: idx)
        } else {
            let host = URL(string: url)?.host ?? url
            bookmarks.append(BrowserBookmark(title: title.isEmpty ? host : title, url: url))
        }
        save()
    }

    public func add(_ bookmark: BrowserBookmark) {
        if let idx = bookmarks.firstIndex(where: { $0.url == bookmark.url }) {
            bookmarks[idx] = bookmark
        } else {
            bookmarks.append(bookmark)
        }
        save()
    }

    public func remove(_ bookmark: BrowserBookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        save()
    }

    public func remove(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        save()
    }

    public func rename(_ bookmark: BrowserBookmark, to title: String) {
        if let idx = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[idx].title = title
            save()
        }
    }

    public var filtered: [BrowserBookmark] {
        guard !searchText.isEmpty else { return bookmarks }
        return bookmarks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.url.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var groupedByFolder: [(folder: String, items: [BrowserBookmark])] {
        let groups = Dictionary(grouping: bookmarks, by: { $0.folder })
        return groups.keys.sorted().map { ($0, groups[$0]?.sorted { $0.title < $1.title } ?? []) }
    }

    public func bookmarksForHost(_ host: String) -> [BrowserBookmark] {
        bookmarks.filter { $0.host == host }
    }
}
