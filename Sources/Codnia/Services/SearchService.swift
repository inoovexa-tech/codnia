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
            let results: [(String, String)]
            if isRegex {
                results = self?.searchContentRegex(root: root, query: query, maxResults: maxResults, caseSensitive: caseSensitive) ?? []
            } else {
                results = FileSystemService.shared.searchContent(root: root, query: query, maxResults: maxResults)
            }
            DispatchQueue.main.async {
                self?.results = results
                self?.isSearching = false
            }
        }
    }

    private func searchContentRegex(root: String, query: String, maxResults: Int, caseSensitive: Bool) -> [(String, String)] {
        let options: NSRegularExpression.Options = caseSensitive ? [] : .caseInsensitive
        guard let regex = try? NSRegularExpression(pattern: query, options: options) else {
            return []
        }
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: root)
        guard let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles) else { return [] }
        var results: [(String, String)] = []
        for case let fileURL as URL in enumerator {
            if results.count >= maxResults { break }
            let ext = fileURL.pathExtension.lowercased()
            let textExts = Set(["txt", "md", "swift", "rs", "ts", "tsx", "js", "jsx", "json", "html", "css", "scss", "yaml", "yml", "toml", "sh", "py", "go", "c", "cpp", "h", "java"])
            guard textExts.contains(ext) else { continue }
            guard let data = try? Data(contentsOf: fileURL),
                  let text = String(data: data, encoding: .utf8)
            else { continue }
            let nsText = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let lineRange = nsText.lineRange(for: match.range)
                let line = nsText.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                results.append((fileURL.path, line))
                break // one match per file
            }
        }
        return results
    }
}
