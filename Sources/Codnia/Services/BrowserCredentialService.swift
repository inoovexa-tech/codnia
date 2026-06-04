import Foundation
import Combine

@MainActor
public final class BrowserCredentialService: ObservableObject {
    @Published public private(set) var credentials: [BrowserSavedCredential] = []
    @Published public var searchText: String = ""
    @Published public private(set) var pendingSave: BrowserSavedCredential?

    private var workspacePath: String = ""
    private let fileName = "credentials.json"

    public init() {}

    public func load(from path: String) {
        workspacePath = path
        let url = (path as NSString).appendingPathComponent(".codnia/browser/\(fileName)")
        guard FileManager.default.fileExists(atPath: url),
              let data = try? Data(contentsOf: URL(fileURLWithPath: url)),
              let decoded = try? JSONDecoder().decode([BrowserSavedCredential].self, from: data) else {
            credentials = []
            return
        }
        credentials = decoded
    }

    public func save() {
        guard !workspacePath.isEmpty else { return }
        let dir = (workspacePath as NSString).appendingPathComponent(".codnia/browser")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let url = (dir as NSString).appendingPathComponent(fileName)
        if let data = try? JSONEncoder().encode(credentials) {
            try? data.write(to: URL(fileURLWithPath: url), options: .atomic)
        }
    }

    public func promptSave(origin: String, username: String, password: String) {
        guard !username.isEmpty, !password.isEmpty else { return }
        let passwordRef = "browser:\(origin):\(username)"
        let cred = BrowserSavedCredential(
            origin: origin,
            username: username,
            passwordRef: passwordRef
        )
        pendingSave = cred
    }

    public func confirmSave(_ credential: BrowserSavedCredential, password: String) {
        BrowserKeychainHelper.save(account: credential.passwordRef, secret: password)
        if let idx = credentials.firstIndex(where: { $0.passwordRef == credential.passwordRef }) {
            credentials[idx] = credential
        } else {
            credentials.append(credential)
        }
        pendingSave = nil
        save()
    }

    public func cancelSave() {
        pendingSave = nil
    }

    public func retrieve(_ credential: BrowserSavedCredential) -> String? {
        BrowserKeychainHelper.get(account: credential.passwordRef)
    }

    public func remove(_ credential: BrowserSavedCredential) {
        BrowserKeychainHelper.delete(account: credential.passwordRef)
        credentials.removeAll { $0.id == credential.id }
        save()
    }

    public func removeAll() {
        for cred in credentials {
            BrowserKeychainHelper.delete(account: cred.passwordRef)
        }
        credentials = []
        save()
    }

    public var filtered: [BrowserSavedCredential] {
        guard !searchText.isEmpty else { return credentials }
        return credentials.filter {
            $0.origin.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var groupedByHost: [(host: String, items: [BrowserSavedCredential])] {
        let groups = Dictionary(grouping: credentials, by: { $0.displayHost })
        return groups.keys.sorted().map { ($0, groups[$0]?.sorted { $0.username < $1.username } ?? []) }
    }

    public func credentials(forHost host: String) -> [BrowserSavedCredential] {
        credentials.filter { $0.displayHost == host }
    }
}
