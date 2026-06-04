import Foundation

public enum BrowserDownloadState: String, Codable, Sendable {
    case pending
    case downloading
    case completed
    case failed
    case cancelled
    case paused
}

public struct BrowserDownload: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var url: String
    public var suggestedFilename: String
    public var mimeType: String
    public var totalBytes: Int64
    public var receivedBytes: Int64
    public var state: BrowserDownloadState
    public var startedAt: Date
    public var finishedAt: Date?
    public var destinationPath: String?
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        url: String,
        suggestedFilename: String,
        mimeType: String = "",
        totalBytes: Int64 = 0,
        receivedBytes: Int64 = 0,
        state: BrowserDownloadState = .pending,
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        destinationPath: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.url = url
        self.suggestedFilename = suggestedFilename
        self.mimeType = mimeType
        self.totalBytes = totalBytes
        self.receivedBytes = receivedBytes
        self.state = state
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.destinationPath = destinationPath
        self.errorMessage = errorMessage
    }

    public var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1.0, Double(receivedBytes) / Double(totalBytes))
    }

    public var displaySize: String {
        let bytes = receivedBytes
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
        return String(format: "%.2f GB", Double(bytes) / (1024 * 1024 * 1024))
    }
}
