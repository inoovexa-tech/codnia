import Foundation
import WebKit
import Combine
import AppKit

@MainActor
public final class BrowserDownloadService: NSObject, ObservableObject {
    @Published public private(set) var downloads: [BrowserDownload] = []
    @Published public var downloadPath: String = "~/Downloads"

    private var workspacePath: String = ""
    private let fileName = "downloads.json"
    private var delegates: [UUID: DownloadDelegate] = [:]

    public override init() {
        super.init()
        if let path = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path {
            downloadPath = path
        }
    }

    public func load(from path: String) {
        workspacePath = path
        let url = (path as NSString).appendingPathComponent(".codnia/browser/\(fileName)")
        guard FileManager.default.fileExists(atPath: url),
              let data = try? Data(contentsOf: URL(fileURLWithPath: url)),
              let decoded = try? JSONDecoder().decode([BrowserDownload].self, from: data) else {
            downloads = []
            return
        }
        downloads = decoded
    }

    public func save() {
        guard !workspacePath.isEmpty else { return }
        let dir = (workspacePath as NSString).appendingPathComponent(".codnia/browser")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let url = (dir as NSString).appendingPathComponent(fileName)
        if let data = try? JSONEncoder().encode(downloads) {
            try? data.write(to: URL(fileURLWithPath: url), options: .atomic)
        }
    }

    public func resolvedDownloadPath() -> String {
        let expanded = (downloadPath as NSString).expandingTildeInPath
        if !FileManager.default.fileExists(atPath: expanded) {
            try? FileManager.default.createDirectory(atPath: expanded, withIntermediateDirectories: true)
        }
        return expanded
    }

    public func startDownload(url: String, suggestedFilename: String, mimeType: String) {
        let download = BrowserDownload(
            url: url,
            suggestedFilename: suggestedFilename.isEmpty ? "download" : suggestedFilename,
            mimeType: mimeType,
            state: .pending
        )
        downloads.insert(download, at: 0)
        save()
        performDownload(download)
    }

    public func cancel(_ download: BrowserDownload) {
        delegates[download.id]?.cancel()
        delegates.removeValue(forKey: download.id)
        update(download.id) { dl in
            var copy = dl
            copy.state = .cancelled
            copy.finishedAt = Date()
            return copy
        }
    }

    public func remove(_ download: BrowserDownload) {
        if let path = download.destinationPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        downloads.removeAll { $0.id == download.id }
        save()
    }

    public func clearCompleted() {
        downloads.removeAll { $0.state == .completed || $0.state == .cancelled || $0.state == .failed }
        save()
    }

    public func revealInFinder(_ download: BrowserDownload) {
        guard let path = download.destinationPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func performDownload(_ download: BrowserDownload) {
        guard let url = URL(string: download.url) else {
            update(download.id) { dl in
                var copy = dl
                copy.state = .failed
                copy.errorMessage = "Invalid URL"
                return copy
            }
            return
        }
        let delegate = DownloadDelegate(id: download.id, service: self)
        delegates[download.id] = delegate
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        delegate.session = session
        delegate.task = task
        update(download.id) { dl in
            var copy = dl
            copy.state = .downloading
            return copy
        }
        task.resume()
    }

    fileprivate func update(_ id: UUID, transform: (BrowserDownload) -> BrowserDownload) {
        guard let idx = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[idx] = transform(downloads[idx])
        save()
    }

    fileprivate func finalize(id: UUID, destinationPath: String?, error: Error?) {
        update(id) { dl in
            var copy = dl
            if let path = destinationPath {
                copy.state = .completed
                copy.destinationPath = path
                if copy.totalBytes == 0 {
                    copy.totalBytes = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? copy.receivedBytes
                }
                if copy.receivedBytes == 0 {
                    copy.receivedBytes = copy.totalBytes
                }
            } else {
                copy.state = .failed
                copy.errorMessage = error?.localizedDescription ?? "Unknown error"
            }
            copy.finishedAt = Date()
            return copy
        }
        delegates.removeValue(forKey: id)
    }
}

final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let id: UUID
    weak var service: BrowserDownloadService?
    var session: URLSession?
    var task: URLSessionDownloadTask?

    init(id: UUID, service: BrowserDownloadService) {
        self.id = id
        self.service = service
    }

    func cancel() {
        task?.cancel()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let total = totalBytesExpectedToWrite
        let written = totalBytesWritten
        Task { @MainActor in
            self.service?.update(self.id) { dl in
                var copy = dl
                copy.receivedBytes = written
                if total > 0 { copy.totalBytes = total }
                return copy
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let suggested = downloadTask.response?.suggestedFilename ?? "download"
        let basePath: String
        if let service = self.service {
            basePath = MainActor.assumeIsolated { service.resolvedDownloadPath() }
        } else {
            basePath = NSTemporaryDirectory()
        }
        let destPath = uniquePath(base: basePath, filename: suggested)
        do {
            if FileManager.default.fileExists(atPath: destPath) {
                try FileManager.default.removeItem(atPath: destPath)
            }
            try FileManager.default.moveItem(at: location, to: URL(fileURLWithPath: destPath))
            Task { @MainActor in
                self.service?.finalize(id: self.id, destinationPath: destPath, error: nil)
            }
        } catch {
            Task { @MainActor in
                self.service?.finalize(id: self.id, destinationPath: nil, error: error)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.service?.finalize(id: self.id, destinationPath: nil, error: error)
            }
        }
    }

    private func uniquePath(base: String, filename: String) -> String {
        let url = URL(fileURLWithPath: base).appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: url.path) { return url.path }
        let ext = (filename as NSString).pathExtension
        let base = (filename as NSString).deletingPathExtension
        var counter = 1
        while true {
            let newName = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            let candidate = URL(fileURLWithPath: base).appendingPathComponent(newName)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate.path
            }
            counter += 1
        }
    }
}
