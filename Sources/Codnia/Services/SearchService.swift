import Foundation
import Combine

public enum SearchMode: String, CaseIterable {
    case all = "All"
    case content = "Content"
    case filename = "Filename"
}

@MainActor
public final class SearchService: ObservableObject {
    @Published public var query: String = ""
    @Published public var results: [(String, String)] = []
    @Published public var isSearching: Bool = false

    @Published public var globalResults: [SearchResult] = []
    @Published public var isGlobalSearching: Bool = false

    private nonisolated static let textExtensions: Set<String> = [
        "txt", "md", "swift", "rs", "ts", "tsx", "js", "jsx",
        "json", "html", "css", "scss", "yaml", "yml", "toml",
        "sh", "py", "go", "c", "cpp", "h", "java"
    ]

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

    public func searchGlobal(projects: [Project], query: String, maxResults: Int = 500, isRegex: Bool = false, caseSensitive: Bool = false, mode: SearchMode = .all) {
        guard !query.isEmpty else {
            globalResults = []
            isGlobalSearching = false
            return
        }

        isGlobalSearching = true
        globalResults = []

        Task { [isRegex, caseSensitive, mode, projects] in
            var allResults: [SearchResult] = []
            let contentLimit = mode == .all ? maxResults / 2 : maxResults

            if mode == .content || mode == .all {
                if isRegex {
                    allResults += self.searchAllContentRegex(projects: projects, query: query, maxResults: contentLimit, caseSensitive: caseSensitive)
                } else {
                    allResults += self.searchAllContentSimple(projects: projects, query: query, maxResults: contentLimit)
                }
            }

            if mode == .filename || mode == .all {
                let filenameLimit = mode == .all ? maxResults - allResults.count : maxResults
                if filenameLimit > 0 {
                    allResults += self.searchAllFileNames(projects: projects, query: query, maxResults: filenameLimit, caseSensitive: caseSensitive)
                }
            }

            self.globalResults = allResults
            self.isGlobalSearching = false
        }
    }

    private func searchAllContentSimple(projects: [Project], query: String, maxResults: Int) -> [SearchResult] {
        var results: [SearchResult] = []
        let fm = FileManager.default
        let textExts = Self.textExtensions

        for project in projects {
            for worktree in project.worktrees {
                let rootURL = URL(fileURLWithPath: worktree.path)
                guard let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles) else { continue }

                for case let fileURL as URL in enumerator {
                    if results.count >= maxResults { break }
                    let ext = fileURL.pathExtension.lowercased()
                    guard textExts.contains(ext) else { continue }
                    guard let data = try? Data(contentsOf: fileURL),
                          let text = String(data: data, encoding: .utf8) else { continue }

                    let lines = text.components(separatedBy: .newlines)
                    for line in lines {
                        if line.localizedCaseInsensitiveContains(query) {
                            results.append(SearchResult(
                                filePath: fileURL.path,
                                matchingLine: line,
                                projectId: project.id,
                                projectName: project.name,
                                worktreeId: worktree.id,
                                worktreeName: worktree.displayName,
                                matchType: .content
                            ))
                            break
                        }
                    }
                }
                if results.count >= maxResults { break }
            }
            if results.count >= maxResults { break }
        }
        return results
    }

    private func searchAllContentRegex(projects: [Project], query: String, maxResults: Int, caseSensitive: Bool) -> [SearchResult] {
        let options: NSRegularExpression.Options = caseSensitive ? [] : .caseInsensitive
        guard let regex = try? NSRegularExpression(pattern: query, options: options) else {
            return []
        }

        var results: [SearchResult] = []
        let fm = FileManager.default
        let textExts = Self.textExtensions

        for project in projects {
            for worktree in project.worktrees {
                let rootURL = URL(fileURLWithPath: worktree.path)
                guard let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles) else { continue }

                for case let fileURL as URL in enumerator {
                    if results.count >= maxResults { break }
                    let ext = fileURL.pathExtension.lowercased()
                    guard textExts.contains(ext) else { continue }
                    guard let data = try? Data(contentsOf: fileURL),
                          let text = String(data: data, encoding: .utf8) else { continue }

                    let nsText = text as NSString
                    let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
                    for match in matches {
                        let lineRange = nsText.lineRange(for: match.range)
                        let line = nsText.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
                        results.append(SearchResult(
                            filePath: fileURL.path,
                            matchingLine: line,
                            projectId: project.id,
                            projectName: project.name,
                            worktreeId: worktree.id,
                            worktreeName: worktree.displayName,
                            matchType: .content
                        ))
                        break
                    }
                }
                if results.count >= maxResults { break }
            }
            if results.count >= maxResults { break }
        }
        return results
    }

    private func searchAllFileNames(projects: [Project], query: String, maxResults: Int, caseSensitive: Bool) -> [SearchResult] {
        var results: [SearchResult] = []
        let fm = FileManager.default

        for project in projects {
            for worktree in project.worktrees {
                let rootURL = URL(fileURLWithPath: worktree.path)
                guard let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles) else { continue }

                for case let fileURL as URL in enumerator {
                    if results.count >= maxResults { break }
                    let filename = fileURL.lastPathComponent
                    let match: Bool
                    if caseSensitive {
                        match = filename.contains(query)
                    } else {
                        match = filename.localizedCaseInsensitiveContains(query)
                    }
                    if match {
                        results.append(SearchResult(
                            filePath: fileURL.path,
                            matchingLine: "",
                            projectId: project.id,
                            projectName: project.name,
                            worktreeId: worktree.id,
                            worktreeName: worktree.displayName,
                            matchType: .filename
                        ))
                    }
                }
                if results.count >= maxResults { break }
            }
            if results.count >= maxResults { break }
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
