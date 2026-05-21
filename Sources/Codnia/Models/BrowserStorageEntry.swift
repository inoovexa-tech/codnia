import Foundation

struct BrowserStorageEntry: Identifiable, Equatable {
    let id: UUID
    let key: String
    let value: String
    let type: StorageType

    enum StorageType: String, CaseIterable {
        case localStorage = "Local Storage"
        case sessionStorage = "Session Storage"
        case cookies = "Cookies"
    }
}
