import Foundation

public struct BrowserSavedCredential: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var origin: String
    public var username: String
    public var passwordRef: String
    public var lastUsed: Date
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        origin: String,
        username: String,
        passwordRef: String,
        lastUsed: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.origin = origin
        self.username = username
        self.passwordRef = passwordRef
        self.lastUsed = lastUsed
        self.createdAt = createdAt
    }

    public var displayHost: String {
        URL(string: origin)?.host ?? origin
    }
}
