import Foundation

@MainActor
public final class FileSystemService {
    public static let shared = FileSystemService()
    private init() {}

    public nonisolated func readFile(path: String) -> String {
        guard
            FileManager.default.isReadableFile(atPath: path),
            let data = FileManager.default.contents(atPath: path),
            let text = String(data: data, encoding: .utf8)
        else { return "" }
        return text
    }

    public nonisolated func readBinaryFile(path: String) -> Data? {
        guard FileManager.default.isReadableFile(atPath: path) else { return nil }
        return FileManager.default.contents(atPath: path)
    }

    public nonisolated func writeFile(path: String, content: String) throws {
        let url = URL(fileURLWithPath: path)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    public nonisolated func createFile(path: String) throws {
        FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
    }

    public nonisolated func createDirectory(path: String) throws {
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path),
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    public nonisolated func delete(path: String) throws {
        try FileManager.default.removeItem(atPath: path)
    }

    public nonisolated func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    public nonisolated func rename(oldPath: String, newPath: String) throws {
        try FileManager.default.moveItem(atPath: oldPath, toPath: newPath)
    }

    public nonisolated func copy(src: String, dst: String) throws {
        try FileManager.default.copyItem(atPath: src, toPath: dst)
    }

    public nonisolated func duplicate(path: String) throws -> String {
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

    public nonisolated func listDirectory(path: String) -> [FileEntry] {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)
        let keys: [URLResourceKey] = [
            .isDirectoryKey, .isHiddenKey, .contentModificationDateKey,
            .fileSizeKey, .totalFileSizeKey, .fileResourceTypeKey
        ]
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys
        ) else { return [] }

        var entries: [FileEntry] = []
        for child in contents {
            let values = try? child.resourceValues(forKeys: Set(keys))
            let isDir = values?.isDirectory ?? false
            let isHidden: Bool = {
                let nameHidden = child.lastPathComponent.hasPrefix(".")
                let flagHidden = values?.isHidden ?? false
                return isDir ? nameHidden : (nameHidden || flagHidden)
            }()
            let modified = values?.contentModificationDate
            let size: Int64? = {
                guard !isDir else { return nil }
                if let s = values?.fileSize { return Int64(s) }
                if let s = values?.totalFileSize { return Int64(s) }
                return nil
            }()
            let kind: String = {
                if isDir { return "Folder" }
                if !child.pathExtension.isEmpty {
                    return child.pathExtension.uppercased() + " File"
                }
                return "File"
            }()
            entries.append(FileEntry(
                name: child.lastPathComponent,
                path: child.path,
                isDirectory: isDir,
                isHidden: isHidden,
                dateModified: modified,
                fileSize: size,
                kind: kind,
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

    public nonisolated static var iCloudDriveURL: URL? {
        let iCloudRoot = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if FileManager.default.fileExists(atPath: iCloudRoot.path) {
            return iCloudRoot
        }
        return nil
    }

    public nonisolated static var mountedVolumes: [URL] {
        let keys: [URLResourceKey] = [
            .volumeIsLocalKey, .volumeIsRemovableKey, .volumeIsInternalKey, .volumeNameKey
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else { return [] }
        return urls
            .filter { url in
                let values = try? url.resourceValues(forKeys: Set(keys))
                if values?.volumeIsInternal == true { return false }
                return true
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    public nonisolated static func displayPath(for path: String) -> String {
        let home = NSHomeDirectory()
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }
}
