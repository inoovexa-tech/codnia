import Foundation

@MainActor
public final class FileSystemService {
    public static let shared = FileSystemService()
    private init() {}

    public func readFile(path: String) -> String {
        guard 
            FileManager.default.isReadableFile(atPath: path),
            let data = FileManager.default.contents(atPath: path),
            let text = String(data: data, encoding: .utf8)
        else { return "" }
        return text
    }

    public func writeFile(path: String, content: String) throws {
        let url = URL(fileURLWithPath: path)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    public func createFile(path: String) throws {
        FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
    }

    public func createDirectory(path: String) throws {
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path),
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    public func delete(path: String) throws {
        try FileManager.default.removeItem(atPath: path)
    }

    public func rename(oldPath: String, newPath: String) throws {
        try FileManager.default.moveItem(atPath: oldPath, toPath: newPath)
    }

    public func copy(src: String, dst: String) throws {
        try FileManager.default.copyItem(atPath: src, toPath: dst)
    }

    public func duplicate(path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension
        let baseName = url.deletingPathExtension().lastPathComponent
        let dir = url.deletingLastPathComponent()

        var counter = 1
        var newPath = dir.appendingPathComponent("\(baseName) copy.\(ext)").path
        while FileManager.default.fileExists(atPath: newPath) {
            newPath = dir.appendingPathComponent("\(baseName) copy \(counter).\(ext)").path
            counter += 1
        }
        try FileManager.default.copyItem(atPath: path, toPath: newPath)
        return newPath
    }

    public func listDirectory(path: String) -> [FileEntry] {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        var entries: [FileEntry] = []
        for child in contents {
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            entries.append(FileEntry(
                name: child.lastPathComponent,
                path: child.path,
                isDirectory: isDir,
                children: nil
            ))
        }
        entries.sort {
            if $0.isDirectory && !$1.isDirectory { return true }
            if !$0.isDirectory && $1.isDirectory { return false }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        return entries
    }

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

    public func searchContent(root: String, query: String, maxResults: Int = 100) -> [(String, String)] {
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: root)
        guard let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles) else { return [] }

        var results: [(String, String)] = []
        for case let fileURL as URL in enumerator {
            if results.count >= maxResults { break }
            // Skip binary files
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
}
