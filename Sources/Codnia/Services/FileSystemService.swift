import Foundation

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

    public func readBinaryFile(path: String) -> Data? {
        guard FileManager.default.isReadableFile(atPath: path) else { return nil }
        return FileManager.default.contents(atPath: path)
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

    public func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
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
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey]
        ) else { return [] }

        var entries: [FileEntry] = []
        for child in contents {
            let resourceValues = try? child.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
            let isDir = resourceValues?.isDirectory ?? false
            let isHidden = resourceValues?.isHidden ?? child.lastPathComponent.hasPrefix(".")
            entries.append(FileEntry(
                name: child.lastPathComponent,
                path: child.path,
                isDirectory: isDir,
                isHidden: isHidden,
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


}
