import Foundation
import WebKit
import Combine

@MainActor
public final class BrowserPersistenceService: NSObject, ObservableObject {
    public static let shared = BrowserPersistenceService()

    @Published public private(set) var currentWorktreeId: String = ""

    private let baseDir: URL
    private var worktreeDirs: [String: URL] = [:]
    private var dataStores: [String: WKWebsiteDataStore] = [:]

    private override init() {
        let fm = FileManager.default
        let appSupport = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.baseDir = appSupport
            .appendingPathComponent("Codnia", isDirectory: true)
            .appendingPathComponent("browser", isDirectory: true)
        super.init()
        try? fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
    }

    public var appSupportBaseDir: URL { baseDir }

    public func browserDirectory(for worktreeId: String) -> URL {
        if let cached = worktreeDirs[worktreeId] { return cached }
        let dir = baseDir.appendingPathComponent(worktreeId, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        worktreeDirs[worktreeId] = dir
        return dir
    }

    public func prepareForWorktree(_ worktreeId: String) {
        currentWorktreeId = worktreeId
        _ = browserDirectory(for: worktreeId)
    }

    public func dataStore(for worktreeId: String) -> WKWebsiteDataStore {
        if let existing = dataStores[worktreeId] { return existing }
        let store = WKWebsiteDataStore.default()
        dataStores[worktreeId] = store
        return store
    }

    public func backupCookies(worktreeId: String, from store: WKWebsiteDataStore) async {
        let cookies = await fetchAllCookies(from: store)
        let data = try? JSONEncoder().encode(cookies)
        guard let data else { return }
        let url = browserDirectory(for: worktreeId)
            .appendingPathComponent("cookies.json")
        try? data.write(to: url, options: .atomic)
    }

    public func restoreCookies(worktreeId: String, into store: WKWebsiteDataStore) async {
        let url = browserDirectory(for: worktreeId)
            .appendingPathComponent("cookies.json")
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let cookies = try? JSONDecoder().decode([SavedHTTPCookie].self, from: data) else {
            return
        }
        let cookieStore = store.httpCookieStore
        for cookie in cookies {
            if let http = cookie.toHTTPCookie() {
                await setCookie(http, on: cookieStore)
            }
        }
    }

    public func backupStorage(worktreeId: String, snapshot: BrowserStorageSnapshot) {
        let url = browserDirectory(for: worktreeId)
            .appendingPathComponent("storage.json")
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
    }

    public func loadStorageSnapshot(worktreeId: String) -> BrowserStorageSnapshot? {
        let url = browserDirectory(for: worktreeId)
            .appendingPathComponent("storage.json")
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BrowserStorageSnapshot.self, from: data)
    }

    public func clearAll(worktreeId: String) async {
        let dir = browserDirectory(for: worktreeId)
        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
        let store = dataStore(for: worktreeId)
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        await store.removeData(ofTypes: dataTypes, for: [])
    }

    public func clear(worktreeId: String, types: Set<BrowserClearType>) async {
        let store = dataStore(for: worktreeId)
        var wkTypes = Set<String>()
        if types.contains(.cookies) {
            wkTypes.insert(WKWebsiteDataTypeCookies)
        }
        if types.contains(.localStorage) || types.contains(.sessionStorage) {
            wkTypes.insert(WKWebsiteDataTypeLocalStorage)
        }
        if types.contains(.indexedDB) || types.contains(.webSQL) {
            wkTypes.insert(WKWebsiteDataTypeIndexedDBDatabases)
            wkTypes.insert(WKWebsiteDataTypeWebSQLDatabases)
        }
        if types.contains(.cache) {
            wkTypes.insert(WKWebsiteDataTypeMemoryCache)
            wkTypes.insert(WKWebsiteDataTypeDiskCache)
        }
        if types.contains(.serviceWorkers) {
            wkTypes.insert(WKWebsiteDataTypeServiceWorkerRegistrations)
        }
        await store.removeData(ofTypes: wkTypes, for: [])

        if types.contains(.localStorage) || types.contains(.sessionStorage) {
            let url = browserDirectory(for: worktreeId)
                .appendingPathComponent("storage.json")
            try? FileManager.default.removeItem(at: url)
        }
        if types.contains(.cookies) {
            let url = browserDirectory(for: worktreeId)
                .appendingPathComponent("cookies.json")
            try? FileManager.default.removeItem(at: url)
        }
    }

    public func export(worktreeId: String) throws -> URL {
        let dir = browserDirectory(for: worktreeId)
        let stagingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("codnia-browser-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for file in files {
                let dest = stagingDir.appendingPathComponent(file.lastPathComponent)
                try? FileManager.default.copyItem(at: file, to: dest)
            }
        }

        let tarPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("codnia-browser-\(worktreeId).tar.gz")
        if FileManager.default.fileExists(atPath: tarPath.path) {
            try FileManager.default.removeItem(at: tarPath)
        }

        try runProcess(executable: "/usr/bin/tar",
                       args: ["-czf", tarPath.path, "-C", stagingDir.path, "."])
        try? FileManager.default.removeItem(at: stagingDir)
        return tarPath
    }

    public func importData(worktreeId: String, from source: URL) throws {
        let dir = browserDirectory(for: worktreeId)
        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("codnia-browser-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try runProcess(executable: "/usr/bin/tar",
                       args: ["-xzf", source.path, "-C", extractDir.path])
        if let files = try? FileManager.default.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil) {
            for file in files {
                let dest = dir.appendingPathComponent(file.lastPathComponent)
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: file, to: dest)
            }
        }
        try? FileManager.default.removeItem(at: extractDir)
    }

    private func runProcess(executable: String, args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "BrowserPersistence", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private func fetchAllCookies(from store: WKWebsiteDataStore) async -> [SavedHTTPCookie] {
        let cookieStore = store.httpCookieStore
        let cookies: [HTTPCookie] = await withCheckedContinuation { continuation in
            cookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
        return cookies.map { SavedHTTPCookie(from: $0) }
    }

    private func setCookie(_ cookie: HTTPCookie, on store: WKHTTPCookieStore) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.setCookie(cookie) {
                continuation.resume()
            }
        }
    }
}

public enum BrowserClearType: String, CaseIterable, Hashable, Sendable {
    case cookies
    case localStorage
    case sessionStorage
    case indexedDB
    case webSQL
    case cache
    case serviceWorkers

    public var displayName: String {
        switch self {
        case .cookies: return "Cookies"
        case .localStorage: return "Local Storage"
        case .sessionStorage: return "Session Storage"
        case .indexedDB: return "IndexedDB"
        case .webSQL: return "WebSQL"
        case .cache: return "Cache"
        case .serviceWorkers: return "Service Workers"
        }
    }
}

public struct BrowserStorageSnapshot: Codable, Equatable, Sendable {
    public var localStorage: [String: String]
    public var sessionStorage: [String: String]
    public var lastUpdated: Date

    public init(localStorage: [String: String] = [:], sessionStorage: [String: String] = [:], lastUpdated: Date = Date()) {
        self.localStorage = localStorage
        self.sessionStorage = sessionStorage
        self.lastUpdated = lastUpdated
    }
}

public struct SavedHTTPCookie: Codable, Equatable, Sendable {
    public var name: String
    public var value: String
    public var domain: String
    public var path: String
    public var isSecure: Bool
    public var isHTTPOnly: Bool
    public var expiresAt: Date?
    public var sameSite: String?

    public init(from cookie: HTTPCookie) {
        self.name = cookie.name
        self.value = cookie.value
        self.domain = cookie.domain
        self.path = cookie.path
        self.isSecure = cookie.isSecure
        self.isHTTPOnly = cookie.isHTTPOnly
        self.expiresAt = cookie.expiresDate
        if #available(macOS 10.15, *) {
            switch cookie.sameSitePolicy {
            case .sameSiteLax: self.sameSite = "Lax"
            case .sameSiteStrict: self.sameSite = "Strict"
            case .none: self.sameSite = "None"
            default: self.sameSite = nil
            }
        } else {
            self.sameSite = nil
        }
    }

    public func toHTTPCookie() -> HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path
        ]
        if isSecure { properties[.secure] = "TRUE" }
        if expiresAt != nil { properties[.expires] = expiresAt as Any }
        if let sameSite = sameSite {
            switch sameSite.lowercased() {
            case "lax": properties[.sameSitePolicy] = "lax"
            case "strict": properties[.sameSitePolicy] = "strict"
            case "none": properties[.sameSitePolicy] = "none"
            default: break
            }
        }
        return HTTPCookie(properties: properties)
    }
}
