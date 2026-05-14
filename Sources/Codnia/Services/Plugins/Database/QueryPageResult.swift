import Foundation

public struct QueryPageResult: Identifiable, Sendable {
    public let id: String
    public let columns: [String]
    public let columnTypes: [String]
    public let rows: [[String?]]
    public let totalCount: Int
    public let page: Int
    public let pageSize: Int
    public let executionTime: TimeInterval
    public let error: String?

    public var pageCount: Int {
        max(1, Int(ceil(Double(totalCount) / Double(pageSize))))
    }

    public var startRow: Int {
        page * pageSize + 1
    }

    public var endRow: Int {
        min((page + 1) * pageSize, totalCount)
    }

    public init(
        id: String = UUID().uuidString,
        columns: [String],
        columnTypes: [String] = [],
        rows: [[String?]],
        totalCount: Int,
        page: Int = 0,
        pageSize: Int = 100,
        executionTime: TimeInterval = 0,
        error: String? = nil
    ) {
        self.id = id
        self.columns = columns
        self.columnTypes = columnTypes
        self.rows = rows
        self.totalCount = totalCount
        self.page = page
        self.pageSize = pageSize
        self.executionTime = executionTime
        self.error = error
    }
}
