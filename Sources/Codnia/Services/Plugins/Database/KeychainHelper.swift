import Foundation
import Security

enum DatabaseKeychainHelper {
    static let service = "com.codnia.app.database"

    static func save(account: String, password: String) {
        BrowserKeychainHelper.save(service: service, account: account, secret: password)
    }

    static func get(account: String) -> String? {
        BrowserKeychainHelper.get(service: service, account: account)
    }

    static func delete(account: String) {
        BrowserKeychainHelper.delete(service: service, account: account)
    }
}
