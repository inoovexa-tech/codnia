import Foundation
import Combine

@MainActor
public final class SearchService: ObservableObject {
    @Published public var query: String = ""
    @Published public var results: [(String, String)] = []
    @Published public var isSearching: Bool = false

    public init() {}

    public func searchFiles(root: String, query: String, maxResults: Int = 100) -> [String] {
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: root)
        guard let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles) else { return [] }
        var results: [String] = []
        for case let fileURL as URL in enumerator {
            if results.count >= maxResults { break }
            let filename = fileURL.lastPathComponent
            if filename.localizedCaseInsensitiveContains(query) {
                results.append(fileURL.path)
            }
        }
        return results
    }

    public func searchContent(root: String, query: String, maxResults: Int = 100, isRegex: Bool = false, caseSensitive: Bool = false) {
        isSearching = true
        Task.detached { [isRegex, caseSensitive] in
            let results: [(String, String)]
            if isRegex {
                results = self.searchContentRegex(root: root, query: query, maxResults: maxResults, caseSensitive: caseSensitive)
            } else {
                results = self.searchContentSimple(root: root, query: query, maxResults: maxResults)
            }
            await MainActor.run {
                self.results = results
                self.isSearching = false
            }
        }
    }

    private nonisolated func searchContentSimple(root: String, query: String, maxResults: Int) -> [(String, String)] {
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
            let lines = text.components(separatedBy: .newlines)
            for line in lines {
                if line.localizedCaseInsensitiveContains(query) {
                    results.append((fileURL.path, line))
                    break
                }
            }
        }
        return results
    }

    private nonisolated func searchContentRegex(root: String, query: String, maxResults: Int, caseSensitive: Bool) -> [(String, String)] {
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
                break
            }
        }
        return results
    }
}
