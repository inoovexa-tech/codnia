import Foundation
import AppKit

public struct SQLCompletionItem: Identifiable, Sendable {
    public let id: String
    public let text: String
    public let displayText: String
    public let type: SQLCompletionType

    public init(text: String, displayText: String? = nil, type: SQLCompletionType) {
        self.id = text
        self.text = text
        self.displayText = displayText ?? text
        self.type = type
    }
}

public enum SQLCompletionType: Sendable {
    case keyword
    case table
    case column
    case schema
}

@MainActor
public class SQLCompletionProvider: ObservableObject {
    @Published public var tables: [(schema: String, table: String)] = []
    @Published public var columns: [(table: String, column: String)] = []

    private let sqlKeywords: [String] = [
        "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "IN", "LIKE", "BETWEEN",
        "IS", "NULL", "AS", "ON", "JOIN", "INNER", "LEFT", "RIGHT", "OUTER", "CROSS",
        "ORDER", "BY", "GROUP", "HAVING", "LIMIT", "OFFSET", "DISTINCT", "UNION", "ALL",
        "EXISTS", "CASE", "WHEN", "THEN", "ELSE", "END",
        "ASC", "DESC",
        "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE",
        "CREATE", "TABLE", "ALTER", "DROP", "INDEX", "VIEW",
        "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "CONSTRAINT", "DEFAULT", "CHECK", "UNIQUE",
        "BEGIN", "COMMIT", "ROLLBACK",
        "COUNT", "SUM", "AVG", "MIN", "MAX", "COALESCE", "CAST",
        "TRUE", "FALSE", "IF", "ELSE",
        "SCHEMA", "DATABASE", "GRANT", "REVOKE", "EXPLAIN", "ANALYZE",
        "TRUNCATE", "REPLACE", "MERGE", "INTERSECT", "EXCEPT",
        "TOP", "HAVING", "WITH", "RECURSIVE", "WINDOW", "OVER", "PARTITION",
        "ROW", "ROWS", "RANGE", "UNBOUNDED", "PRECEDING", "FOLLOWING",
        "CURRENT", "FETCH", "NEXT", "ONLY", "ROW_COUNT",
    ]

    public var allItems: [SQLCompletionItem] {
        var items: [SQLCompletionItem] = []
        for kw in sqlKeywords {
            items.append(SQLCompletionItem(text: kw, type: .keyword))
        }
        for (schema, table) in tables {
            items.append(SQLCompletionItem(text: table, displayText: "\(schema).\(table)", type: .table))
        }
        for (table, column) in columns {
            items.append(SQLCompletionItem(text: column, displayText: "\(table).\(column)", type: .column))
        }
        return items
    }

    public func items(matching prefix: String) -> [SQLCompletionItem] {
        guard !prefix.isEmpty else { return allItems }
        let lower = prefix.lowercased()
        return allItems.filter { $0.text.lowercased().hasPrefix(lower) || $0.displayText.lowercased().hasPrefix(lower) }
    }

    public init() {}

    public func updateSchema(tables: [(String, String)], columns: [(String, String)]) {
        self.tables = tables.map { (schema: $0.0, table: $0.1) }
        self.columns = columns.map { (table: $0.0, column: $0.1) }
    }
}
