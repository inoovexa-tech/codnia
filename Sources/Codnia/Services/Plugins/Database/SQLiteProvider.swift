import Foundation
import SQLite3

final class SQLiteProvider: DatabaseProvider, @unchecked Sendable {
    var type: DatabaseType { .sqlite }

    private var connections: [String: OpaquePointer] = [:]
    private var configs: [String: ConnectionConfig] = [:]
    private let lock = NSLock()

    func open(config: ConnectionConfig, password: String) async throws -> String {
        guard let filePath = config.filePath, !filePath.isEmpty else {
            throw SQLiteError.invalidPath
        }
        let handle = UUID().uuidString
        var db: OpaquePointer?
        let rc = sqlite3_open(filePath, &db)
        guard rc == SQLITE_OK, let db else {
            throw SQLiteError.openFailed(String(cString: sqlite3_errmsg(db)))
        }
        lock.withLock {
            connections[handle] = db
            configs[handle] = config
        }
        return handle
    }

    func close(handle: String) async throws {
        let db: OpaquePointer? = lock.withLock {
            configs.removeValue(forKey: handle)
            return connections.removeValue(forKey: handle)
        }
        if let db {
            sqlite3_close(db)
        }
    }

    func setBackendPID(handle: String, pid: Int) {}

    private func db(for handle: String) throws -> OpaquePointer {
        lock.lock()
        defer { lock.unlock() }
        guard let db = connections[handle] else {
            throw DatabaseError.notConnected
        }
        return db
    }

    // MARK: - Schema Browsing

    func fetchDatabases(handle: String) async throws -> [DatabaseInfo] {
        guard let filePath = lock.withLock({ configs[handle]?.filePath }) else {
            return [DatabaseInfo(name: "main")]
        }
        let url = URL(fileURLWithPath: filePath)
        return [DatabaseInfo(name: url.lastPathComponent)]
    }

    func fetchSchemas(handle: String) async throws -> [SchemaInfo] {
        return [SchemaInfo(name: "main")]
    }

    func fetchTables(handle: String, schema: String) async throws -> [TableInfo] {
        let rows = try runSQL(handle: handle, sql: "SELECT name, type FROM sqlite_master WHERE type IN ('table','view') AND name NOT LIKE 'sqlite_%' ORDER BY name")
        return rows.map { row in
            let tableType: TableInfo.TableType = row[1] == "view" ? .view : .table
            return TableInfo(schema: "main", name: row[0] ?? "?", tableType: tableType)
        }
    }

    func fetchColumns(handle: String, table: TableID) async throws -> [ColumnInfo] {
        let rows = try runSQL(handle: handle, sql: "PRAGMA table_info('\(escape(table.table))')")
        return rows.map { row in
            ColumnInfo(
                name: row[1] ?? "?",
                dataType: row[2] ?? "text",
                isNullable: (row[3] as NSString?)?.intValue == 0,
                defaultValue: row[4]
            )
        }
    }

    func fetchFunctions(handle: String, schema: String) async throws -> [FunctionInfo] {
        return []
    }

    func fetchProcedures(handle: String, schema: String) async throws -> [ProcedureInfo] {
        return []
    }

    // MARK: - Query Execution

    func execute(handle: String, query sql: String, page: Int, pageSize: Int, orderBy: String?) async throws -> QueryPageResult {
        let start = Date()
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ";"))
        let upper = trimmed.uppercased()

        guard upper.hasPrefix("SELECT") || upper.hasPrefix("WITH") || upper.hasPrefix("VALUES") || upper.hasPrefix("TABLE") || upper.hasPrefix("PRAGMA") else {
            do {
                let affected = try runMutation(handle: handle, sql: trimmed)
                let elapsed = Date().timeIntervalSince(start)
                return QueryPageResult(
                    columns: ["Result"],
                    columnTypes: ["text"],
                    rows: [["Query executed successfully. Rows affected: \(affected)"]],
                    totalCount: 1, page: 0, pageSize: 1, executionTime: elapsed
                )
            } catch {
                throw error
            }
        }

        let countSQL = "SELECT COUNT(*) FROM (\(trimmed)) AS _cnt"
        let countRows: [[String?]]
        do {
            countRows = try runSQL(handle: handle, sql: countSQL)
        } catch {
            let elapsed = Date().timeIntervalSince(start)
            return QueryPageResult(
                columns: [], rows: [], totalCount: 0,
                page: page, pageSize: pageSize,
                executionTime: elapsed,
                error: "Count query failed: \(error.localizedDescription)"
            )
        }

        let totalCount: Int = {
            guard let firstRow = countRows.first, let cell = firstRow.first, let value = cell, let count = Int(value) else { return 0 }
            return count
        }()

        let offset = page * pageSize
        let orderClause = orderBy.map { " ORDER BY \($0)" } ?? ""
        let pageSQL = "\(trimmed)\(orderClause) LIMIT \(pageSize) OFFSET \(offset)"

        var columns: [String] = []
        var columnTypes: [String] = []
        var rows: [[String?]] = []

        do {
            let result = try runSQLWithColumns(handle: handle, sql: pageSQL)
            columns = result.columns
            columnTypes = result.columnTypes
            rows = result.rows
        } catch {
            let elapsed = Date().timeIntervalSince(start)
            return QueryPageResult(
                columns: columns, columnTypes: columnTypes, rows: rows,
                totalCount: totalCount, page: page, pageSize: pageSize,
                executionTime: elapsed, error: error.localizedDescription
            )
        }

        let elapsed = Date().timeIntervalSince(start)
        return QueryPageResult(
            columns: columns, columnTypes: columnTypes, rows: rows,
            totalCount: totalCount, page: page, pageSize: pageSize,
            executionTime: elapsed
        )
    }

    // MARK: - DML

    func fetchPrimaryKeyColumns(handle: String, table: TableID) async throws -> [String] {
        let rows = try runSQL(handle: handle, sql: "PRAGMA table_info('\(escape(table.table))')")
        return rows.compactMap { row in
            guard let pk = (row[5] as NSString?)?.intValue, pk > 0 else { return nil }
            return row[1]
        }
    }

    func updateRow(handle: String, table: TableID, set: [(column: String, value: String?)], primaryKeyValues: [(column: String, value: String?)]) async throws -> Int {
        let setClause = set.map { "\"\(escapeIdentifier($0.column))\" = \(escapeValue($0.value))" }.joined(separator: ", ")
        let whereClause = primaryKeyValues.map { "\"\(escapeIdentifier($0.column))\" = \(escapeValue($0.value))" }.joined(separator: " AND ")
        let sql = "UPDATE \"\(escapeIdentifier(table.table))\" SET \(setClause) WHERE \(whereClause)"
        return try runMutation(handle: handle, sql: sql)
    }

    func insertRow(handle: String, table: TableID, columns: [String], values: [String?]) async throws -> [String: String?]? {
        let colList = columns.map { "\"\(escapeIdentifier($0))\"" }.joined(separator: ", ")
        let valList = values.map { escapeValue($0) }.joined(separator: ", ")
        let sql = "INSERT INTO \"\(escapeIdentifier(table.table))\" (\(colList)) VALUES (\(valList))"
        _ = try runMutation(handle: handle, sql: sql)
        return nil
    }

    func deleteRow(handle: String, table: TableID, primaryKeyValues: [(column: String, value: String?)]) async throws -> Int {
        let whereClause = primaryKeyValues.map { "\"\(escapeIdentifier($0.column))\" = \(escapeValue($0.value))" }.joined(separator: " AND ")
        let sql = "DELETE FROM \"\(escapeIdentifier(table.table))\" WHERE \(whereClause)"
        return try runMutation(handle: handle, sql: sql)
    }

    // MARK: - DDL

    func fetchTableDDL(handle: String, table: TableID) async throws -> String {
        let rows = try runSQL(handle: handle, sql: "SELECT sql FROM sqlite_master WHERE name = '\(escape(table.table))' AND type = 'table'")
        guard let row = rows.first, let ddl = row.first, let result = ddl else {
            throw DDLMethodError.notImplemented("fetchTableDDL")
        }
        return result
    }

    func createTable(handle: String, schema: String, name: String, columns: [NewColumnInfo]) async throws {
        var colDefs: [String] = []
        var pkCols: [String] = []
        for col in columns {
            var def = "\"\(escapeIdentifier(col.name))\" \(col.type)"
            if !col.isNullable { def += " NOT NULL" }
            if let dv = col.defaultValue, !dv.isEmpty { def += " DEFAULT \(dv)" }
            if col.isPrimaryKey { pkCols.append("\"\(escapeIdentifier(col.name))\"") }
            colDefs.append(def)
        }
        if !pkCols.isEmpty {
            colDefs.append("PRIMARY KEY (\(pkCols.joined(separator: ", ")))")
        }
        let sql = "CREATE TABLE \"\(escapeIdentifier(name))\" (\n  \(colDefs.joined(separator: ",\n  "))\n)"
        try runMutation(handle: handle, sql: sql)
    }

    func dropTable(handle: String, table: TableID, cascade: Bool) async throws {
        let sql = "DROP TABLE \"\(escapeIdentifier(table.table))\""
        try runMutation(handle: handle, sql: sql)
    }

    func addColumn(handle: String, table: TableID, column: NewColumnInfo) async throws {
        var def = "\"\(escapeIdentifier(column.name))\" \(column.type)"
        if !column.isNullable { def += " NOT NULL" }
        if let dv = column.defaultValue, !dv.isEmpty { def += " DEFAULT \(dv)" }
        let sql = "ALTER TABLE \"\(escapeIdentifier(table.table))\" ADD COLUMN \(def)"
        try runMutation(handle: handle, sql: sql)
    }

    func dropColumn(handle: String, table: TableID, column: String) async throws {
        let sql = "ALTER TABLE \"\(escapeIdentifier(table.table))\" DROP COLUMN \"\(escapeIdentifier(column))\""
        try runMutation(handle: handle, sql: sql)
    }

    func alterColumn(handle: String, table: TableID, column: String, newName: String?, newType: String?, nullable: Bool?, defaultValue: String?) async throws {
        if let name = newName {
            let sql = "ALTER TABLE \"\(escapeIdentifier(table.table))\" RENAME COLUMN \"\(escapeIdentifier(column))\" TO \"\(escapeIdentifier(name))\""
            try runMutation(handle: handle, sql: sql)
        }
        if newType != nil || nullable != nil || defaultValue != nil {
            throw DDLMethodError.notImplemented("alterColumn type/nullable/default requires table recreation in SQLite")
        }
    }

    func fetchIndexes(handle: String, table: TableID) async throws -> [IndexInfo] {
        let rows = try runSQL(handle: handle, sql: "PRAGMA index_list('\(escape(table.table))')")
        var indexes: [IndexInfo] = []
        for row in rows {
            guard let idxName = row[1], let unique = (row[2] as NSString?)?.intValue else { continue }
            let infoRows = try runSQL(handle: handle, sql: "PRAGMA index_info('\(escape(idxName))')")
            let cols = infoRows.compactMap { r in r[2] }
            indexes.append(IndexInfo(
                name: idxName,
                columns: cols,
                isUnique: unique == 1,
                table: table.table,
                schema: "main"
            ))
        }
        return indexes
    }

    func createIndex(handle: String, table: TableID, name: String, columns: [String], unique: Bool) async throws {
        let uniqueSQL = unique ? "UNIQUE " : ""
        let colList = columns.map { "\"\(escapeIdentifier($0))\"" }.joined(separator: ", ")
        let sql = "CREATE \(uniqueSQL)INDEX \"\(escapeIdentifier(name))\" ON \"\(escapeIdentifier(table.table))\" (\(colList))"
        try runMutation(handle: handle, sql: sql)
    }

    func dropIndex(handle: String, indexName: String, table: TableID) async throws {
        let sql = "DROP INDEX \"\(escapeIdentifier(indexName))\""
        try runMutation(handle: handle, sql: sql)
    }

    func cancel(handle: String) async throws {
        let db = try db(for: handle)
        sqlite3_interrupt(db)
    }

    // MARK: - Triggers

    func fetchTriggers(handle: String, schema: String) async throws -> [TriggerInfo] {
        let rows = try runSQL(handle: handle, sql: "SELECT name, tbl_name, sql FROM sqlite_master WHERE type = 'trigger' ORDER BY name")
        return rows.map {
            TriggerInfo(name: $0[0] ?? "?", table: $0[1] ?? "", schema: "main", definition: $0[2])
        }
    }

    func dropTrigger(handle: String, schema: String, trigger: String, table: String) async throws {
        try runMutation(handle: handle, sql: "DROP TRIGGER IF EXISTS \"\(escapeIdentifier(trigger))\"")
    }

    // MARK: - Sequences (no native sequences in SQLite, map to sqlite_sequence)

    func fetchSequences(handle: String, schema: String) async throws -> [SequenceInfo] {
        let rows = try runSQL(handle: handle, sql: "SELECT name, seq FROM sqlite_sequence ORDER BY name")
        return rows.map {
            let val = ($0[1] ?? "0").flatMap { Int($0) } ?? 0
            return SequenceInfo(name: $0[0] ?? "?", schema: "main", dataType: "INTEGER", currentValue: val)
        }
    }

    func dropSequence(handle: String, schema: String, sequence: String) async throws {
        try runMutation(handle: handle, sql: "DELETE FROM sqlite_sequence WHERE name = '\(escape(sequence))'")
    }

    // MARK: - Constraints

    func fetchConstraints(handle: String, table: TableID) async throws -> [ConstraintInfo] {
        let ddl = try await fetchTableDDL(handle: handle, table: table)
        var constraints: [ConstraintInfo] = []
        let lines = ddl.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix("PRIMARY KEY") {
                let cols = parseConstraintColumns(from: trimmed)
                constraints.append(ConstraintInfo(name: "PRIMARY KEY", type: .primaryKey, table: table.table, schema: "main", columns: cols, definition: trimmed))
            } else if trimmed.uppercased().hasPrefix("FOREIGN KEY") {
                let parts = trimmed.components(separatedBy: " ")
                let name = parts.count > 2 ? parts[2] : "FK"
                constraints.append(ConstraintInfo(name: "FK_\(name)", type: .foreignKey, table: table.table, schema: "main", columns: [], definition: trimmed))
            } else if trimmed.uppercased().hasPrefix("UNIQUE") {
                let cols = parseConstraintColumns(from: trimmed)
                constraints.append(ConstraintInfo(name: "UNIQUE", type: .unique, table: table.table, schema: "main", columns: cols, definition: trimmed))
            } else if trimmed.uppercased().hasPrefix("CHECK") {
                constraints.append(ConstraintInfo(name: "CHECK", type: .check, table: table.table, schema: "main", columns: [], definition: trimmed))
            }
        }
        return constraints
    }

    private func parseConstraintColumns(from def: String) -> [String] {
        guard let start = def.firstIndex(of: "("), let end = def.lastIndex(of: ")") else { return [] }
        let inner = def[def.index(after: start)..<end]
        return inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "") }
    }

    func dropConstraint(handle: String, table: TableID, constraint: String) async throws {
        throw DDLMethodError.notImplemented("dropConstraint requires table recreation in SQLite")
    }

    func addForeignKey(handle: String, table: TableID, name: String, columns: [String], refTable: TableID, refColumns: [String], onDelete: String?, onUpdate: String?) async throws {
        throw DDLMethodError.notImplemented("addForeignKey requires table recreation in SQLite")
    }

    // MARK: - Table Properties

    func fetchTableStats(handle: String, table: TableID) async throws -> TableStats {
        let countRows = try runSQL(handle: handle, sql: "SELECT COUNT(*) FROM \"\(escapeIdentifier(table.table))\"")
        let count = countRows.first?.first.flatMap { $0 }.flatMap { Int($0) }
        return TableStats(
            estimatedRowCount: count,
            exactRowCount: count
        )
    }

    // MARK: - Routine Source

    func fetchRoutineSource(handle: String, schema: String, name: String, type: RoutineType) async throws -> String {
        switch type {
        case .view:
            let rows = try runSQL(handle: handle, sql: "SELECT sql FROM sqlite_master WHERE name = '\(escape(name))' AND type = 'view'")
            guard let row = rows.first, let source = row.first, let result = source else {
                throw DDLMethodError.notImplemented("fetchRoutineSource: view not found")
            }
            return result
        case .function, .procedure:
            throw DDLMethodError.notImplemented("fetchRoutineSource: SQLite does not support functions/procedures")
        }
    }

    func updateRoutine(handle: String, schema: String, name: String, type: RoutineType, source: String) async throws {
        switch type {
        case .view:
            try runMutation(handle: handle, sql: "DROP VIEW IF EXISTS \"\(escapeIdentifier(name))\"")
            try runMutation(handle: handle, sql: source)
        case .function, .procedure:
            throw DDLMethodError.notImplemented("updateRoutine: SQLite does not support functions/procedures")
        }
    }

    // MARK: - Dependencies

    func fetchDependencies(handle: String, schema: String, table: String) async throws -> [String] {
        []
    }

    // MARK: - Table Operations

    func renameTable(handle: String, table: TableID, newName: String) async throws {
        try runMutation(handle: handle, sql: "ALTER TABLE \"\(escapeIdentifier(table.table))\" RENAME TO \"\(escapeIdentifier(newName))\"")
    }

    func moveTable(handle: String, table: TableID, newSchema: String) async throws {
        throw DDLMethodError.notImplemented("moveTable")
    }

    func copyTable(handle: String, table: TableID, newName: String, copyData: Bool) async throws {
        let sql = "CREATE TABLE \"\(escapeIdentifier(newName))\" AS SELECT * FROM \"\(escapeIdentifier(table.table))\""
        try runMutation(handle: handle, sql: sql)
        if !copyData {
            try runMutation(handle: handle, sql: "DELETE FROM \"\(escapeIdentifier(newName))\"")
        }
    }

    // MARK: - Transactions

    func beginTransaction(handle: String) async throws {
        try runMutation(handle: handle, sql: "BEGIN")
    }

    func commitTransaction(handle: String) async throws {
        try runMutation(handle: handle, sql: "COMMIT")
    }

    func rollbackTransaction(handle: String) async throws {
        try runMutation(handle: handle, sql: "ROLLBACK")
    }

    var supportsTransactions: Bool { true }

    // MARK: - Identifier Quoting

    func quoteIdentifier(_ name: String) -> String {
        let escaped = name.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    // MARK: - SQLite Helpers

    private struct SQLiteColumnResult {
        let columns: [String]
        let columnTypes: [String]
        let rows: [[String?]]
    }

    private func runSQLWithColumns(handle: String, sql: String) throws -> SQLiteColumnResult {
        let db = try db(for: handle)
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let stmt else {
            throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }

        let colCount = sqlite3_column_count(stmt)
        let columns: [String] = (0..<colCount).map {
            String(cString: sqlite3_column_name(stmt, $0))
        }
        let columnTypes: [String] = (0..<colCount).map { i in
            if let ptr = sqlite3_column_decltype(stmt, i) {
                String(cString: ptr)
            } else {
                "TEXT"
            }
        }
        var rows: [[String?]] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String?] = []
            for i in 0..<colCount {
                row.append(decodeColumn(stmt, index: i))
            }
            rows.append(row)
        }

        return SQLiteColumnResult(columns: columns, columnTypes: columnTypes, rows: rows)
    }

    private func runSQL(handle: String, sql: String) throws -> [[String?]] {
        let result = try runSQLWithColumns(handle: handle, sql: sql)
        return result.rows
    }

    @discardableResult
    private func runMutation(handle: String, sql: String) throws -> Int {
        let db = try db(for: handle)
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let stmt else {
            throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }

        let stepRC = sqlite3_step(stmt)
        guard stepRC == SQLITE_DONE || stepRC == SQLITE_ROW else {
            throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }

        return Int(sqlite3_changes(db))
    }

    private func decodeColumn(_ stmt: OpaquePointer, index: Int32) -> String? {
        let type = sqlite3_column_type(stmt, index)
        switch type {
        case SQLITE_NULL:
            return nil
        case SQLITE_INTEGER:
            let val = sqlite3_column_int64(stmt, index)
            return String(val)
        case SQLITE_FLOAT:
            let val = sqlite3_column_double(stmt, index)
            return String(val)
        case SQLITE_TEXT:
            guard let cStr = sqlite3_column_text(stmt, index) else { return nil }
            return String(cString: cStr)
        case SQLITE_BLOB:
            guard let bytes = sqlite3_column_blob(stmt, index) else { return nil }
            let length = sqlite3_column_bytes(stmt, index)
            let data = Data(bytes: bytes, count: Int(length))
            return "0x" + data.map { String(format: "%02x", $0) }.joined()
        default:
            return nil
        }
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private func escapeIdentifier(_ ident: String) -> String {
        ident.replacingOccurrences(of: "\"", with: "\"\"")
    }

    private func escapeValue(_ value: String?) -> String {
        guard let value else { return "NULL" }
        let escaped = value.replacingOccurrences(of: "'", with: "''")
        return "'\(escaped)'"
    }
}

enum SQLiteError: LocalizedError {
    case invalidPath
    case openFailed(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPath: return "No file path specified for SQLite database"
        case .openFailed(let msg): return "Failed to open SQLite database: \(msg)"
        case .queryFailed(let msg): return "SQLite query failed: \(msg)"
        }
    }
}
