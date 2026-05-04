import Foundation
import Combine

public final class SearchService: ObservableObject {
    @Published public var query: String = ""
    @Published public var results: [(String, String)] = []
    @Published public var isSearching: Bool = false

    public init() {}

    public func searchFiles(root: String, query: String, maxResults: Int = 100) -> [String] {
        FileSystemService.shared.searchFiles(root: root, query: query, maxResults: maxResults)
    }

    public func searchContent(root: String, query: String, maxResults: Int = 100, isRegex: Bool = false, caseSensitive: Bool = false) {
        isSearching = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let results = FileSystemService.shared.searchContent(root: root, query: query, maxResults: maxResults)
            DispatchQueue.main.async {
                self?.results = results
                self?.isSearching = false
            }
        }
    }
}
