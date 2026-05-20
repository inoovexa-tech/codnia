import Foundation

struct QueryHistoryItem: Identifiable {
    let id: UUID
    let sql: String
    let timestamp: Date
    let connectionName: String
    let duration: TimeInterval
    let rowCount: Int
    let isError: Bool
}
