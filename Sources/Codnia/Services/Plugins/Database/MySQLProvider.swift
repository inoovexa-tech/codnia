import Foundation
import Logging

@preconcurrency import MySQLNIO
import NIOPosix

final class MySQLProvider: DatabaseProvider, @unchecked Sendable {
    var type: DatabaseType { .mysql }

    private let eventLoopGroup: EventLoopGroup
    private var connections: [String: MySQLConnection] = [:]
    private var configs: [String: ConnectionConfig] = [:]
    private var passwords: [String: String] = [:]
    private var connectionIDs: [String: UInt64] = [:]
    private let lock = NSLock()
    private let logger = Logger(label: "com.codnia.app.mysql")

    init() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    deinit {
        let group = eventLoopGroup
        Task.detached { try? await group.shutdownGracefully() }
    }

    func open(config: ConnectionConfig, password: String) async throws -> String {
        let handle = UUID().uuidString
        let conn = try await makeConnection(config: config, password: password)
        lock.withLock {
            connections[handle] = conn
            configs[handle] = config
            passwords[handle] = password
        }
        return handle
    }

    func close(handle: String) async throws {
        let conn: MySQLConnection? = lock.withLock {
            let c = connections.removeValue(forKey: handle)
            configs.removeValue(forKey: handle)
            passwords.removeValue(forKey: handle)
            connectionIDs.removeValue(forKey: handle)
            return c
        }
        try? await conn?.close().get()
    }

    func setBackendPID(handle: String, pid: Int) {
        lock.withLock { connectionIDs[handle] = UInt64(pid) }
    }

    private func makeConnection(config: ConnectionConfig, password: String) async throws -> MySQLConnection {
        let tls: TLSConfiguration? = config.useSSL ? .makeClientConfiguration() : nil
        return try await MySQLConnection.connect(
            to: .makeAddressResolvingHost(config.host, port: config.port),
            username: config.user,
            database: config.database ?? "",
            password: password,
            tlsConfiguration: tls,
            serverHostname: config.host,
            on: eventLoopGroup.next()
        ).get()
    }

    // MARK: - Schema Browsing

    func fetchDatabases(handle: String) async throws -> [DatabaseInfo] {
        let rows = try await runQuery(handle: handle, sql: "SHOW DATABASES ORDER BY `Database`")
        return rows.map { DatabaseInfo(name: $0[0] ?? "?") }
    }

    func fetchSchemas(handle: String) async throws -> [SchemaInfo] {
        let config = lock.withLock { configs[handle] }
        guard let db = config?.database, !db.isEmpty else {
            let rows = try await runQuery(handle: handle, sql: "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA ORDER BY SCHEMA_NAME")
            return rows.map { SchemaInfo(name: $0[0] ?? "?") }
        }
        return [SchemaInfo(name: db)]
    }

    func fetchTables(handle: String, schema: String) async throws -> [TableInfo] {
        let sql = """
        SELECT TABLE_NAME, TABLE_TYPE FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = '\(escape(schema))' ORDER BY TABLE_NAME
        """
        let rows = try await runQuery(handle: handle, sql: sql)
        return rows.map { row in
            let type: TableInfo.TableType = row[1] == "VIEW" ? .view : .table
            return TableInfo(schema: schema, name: row[0] ?? "?", tableType: type)
        }
    }

    func fetchColumns(handle: String, table: TableID) async throws -> [ColumnInfo] {
        let sql = """
        SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = '\(escape(table.schema))' AND TABLE_NAME = '\(escape(table.table))'
        ORDER BY ORDINAL_POSITION
        """
        let rows = try await runQuery(handle: handle, sql: sql)
        return rows.map { row in
            ColumnInfo(
                name: row[0] ?? "?",
                dataType: row[1] ?? "?",
                isNullable: row[2] == "YES",
                defaultValue: row[3]
            )
        }
    }

    func fetchFunctions(handle: String, schema: String) async throws -> [FunctionInfo] {
        let sql = """
        SELECT ROUTINE_NAME, DATA_TYPE
        FROM INFORMATION_SCHEMA.ROUTINES
        WHERE ROUTINE_SCHEMA = '\(escape(schema))' AND ROUTINE_TYPE = 'FUNCTION'
        ORDER BY ROUTINE_NAME
        """
        let rows = try await runQuery(handle: handle, sql: sql)
        return rows.map { FunctionInfo(name: $0[0] ?? "?", returnType: $0[1], schema: schema) }
    }

    func fetchProcedures(handle: String, schema: String) async throws -> [ProcedureInfo] {
        let sql = """
        SELECT ROUTINE_NAME
        FROM INFORMATION_SCHEMA.ROUTINES
        WHERE ROUTINE_SCHEMA = '\(escape(schema))' AND ROUTINE_TYPE = 'PROCEDURE'
        ORDER BY ROUTINE_NAME
        """
        let rows = try await runQuery(handle: handle, sql: sql)
        return rows.map { ProcedureInfo(name: $0[0] ?? "?", schema: schema) }
    }

    // MARK: - Query Execution

    func execute(handle: String, query sql: String, page: Int, pageSize: Int, orderBy: String?) async throws -> QueryPageResult {
        let start = Date()
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ";"))
        let upper = trimmed.uppercased()

        guard upper.hasPrefix("SELECT") || upper.hasPrefix("WITH") || upper.hasPrefix("VALUES") || upper.hasPrefix("TABLE") else {
            do {
                let affected = try await runMutation(handle: handle, sql: trimmed)
                let elapsed = Date().timeIntervalSince(start)
                return QueryPageResult(
                    columns: ["Result"],
                    columnTypes: ["text"],
                    rows: [["Query executed successfully. Rows affected: \(affected)"]],
                    totalCount: 1,
                    page: 0,
                    pageSize: 1,
                    executionTime: elapsed
                )
            } catch {
                throw error
            }
        }

        let countSQL = "SELECT COUNT(*) FROM (\(trimmed)) AS _cnt"
        let countRows: [[String?]]
        do {
            countRows = try await runQuery(handle: handle, sql: countSQL)
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
            let conn = try connection(for: handle)
            let mysqlRows = try await conn.simpleQuery(pageSQL).get()
            if let first = mysqlRows.first {
                columns = first.columnDefinitions.map(\.name)
                columnTypes = first.columnDefinitions.map { $0.columnType.name }
            }
            for mysqlRow in mysqlRows {
                var rowData: [String?] = []
                for i in 0..<columns.count {
                    rowData.append(decodeCell(mysqlRow, at: i))
                }
                rows.append(rowData)
            }
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
        let sql = """
        SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
        WHERE TABLE_SCHEMA = '\(escape(table.schema))' AND TABLE_NAME = '\(escape(table.table))'
        AND CONSTRAINT_NAME = 'PRIMARY' ORDER BY ORDINAL_POSITION
        """
        let rows = try await runQuery(handle: handle, sql: sql)
        return rows.compactMap { $0.first ?? nil }
    }

    func updateRow(handle: String, table: TableID, set: [(column: String, value: String?)], primaryKeyValues: [(column: String, value: String?)]) async throws -> Int {
        let setClause = set.map { "`\(escapeIdentifier($0.column))` = \(escapeValue($0.value))" }.joined(separator: ", ")
        let whereClause = primaryKeyValues.map { "`\(escapeIdentifier($0.column))` = \(escapeValue($0.value))" }.joined(separator: " AND ")
        let sql = "UPDATE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))` SET \(setClause) WHERE \(whereClause)"
        return try await runMutation(handle: handle, sql: sql)
    }

    func insertRow(handle: String, table: TableID, columns: [String], values: [String?]) async throws -> [String: String?]? {
        let colList = columns.map { "`\(escapeIdentifier($0))`" }.joined(separator: ", ")
        let valList = values.map { escapeValue($0) }.joined(separator: ", ")
        let sql = "INSERT INTO `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))` (\(colList)) VALUES (\(valList))"
        _ = try await runMutation(handle: handle, sql: sql)
        return nil
    }

    func deleteRow(handle: String, table: TableID, primaryKeyValues: [(column: String, value: String?)]) async throws -> Int {
        let whereClause = primaryKeyValues.map { "`\(escapeIdentifier($0.column))` = \(escapeValue($0.value))" }.joined(separator: " AND ")
        let sql = "DELETE FROM `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))` WHERE \(whereClause)"
        return try await runMutation(handle: handle, sql: sql)
    }

    // MARK: - DDL

    func fetchTableDDL(handle: String, table: TableID) async throws -> String {
        let sql = "SHOW CREATE TABLE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))`"
        let rows = try await runQuery(handle: handle, sql: sql)
        guard let row = rows.first, row.count > 1 else { throw DDLMethodError.notImplemented("fetchTableDDL") }
        return row[1] ?? ""
    }

    func createTable(handle: String, schema: String, name: String, columns: [NewColumnInfo]) async throws {
        var colDefs: [String] = []
        var pkCols: [String] = []
        for col in columns {
            var def = "`\(escapeIdentifier(col.name))` \(col.type)"
            if !col.isNullable { def += " NOT NULL" }
            if let dv = col.defaultValue, !dv.isEmpty { def += " DEFAULT \(dv)" }
            if col.isPrimaryKey { pkCols.append("`\(escapeIdentifier(col.name))`") }
            colDefs.append(def)
        }
        if !pkCols.isEmpty {
            colDefs.append("PRIMARY KEY (\(pkCols.joined(separator: ", ")))")
        }
        let sql = "CREATE TABLE `\(escapeIdentifier(schema))`.`\(escapeIdentifier(name))` (\n  \(colDefs.joined(separator: ",\n  "))\n)"
        try await runMutation(handle: handle, sql: sql)
    }

    func dropTable(handle: String, table: TableID, cascade: Bool) async throws {
        let sql = "DROP TABLE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))`"
        try await runMutation(handle: handle, sql: sql)
    }

    func addColumn(handle: String, table: TableID, column: NewColumnInfo) async throws {
        var def = "`\(escapeIdentifier(column.name))` \(column.type)"
        if !column.isNullable { def += " NOT NULL" }
        if let dv = column.defaultValue, !dv.isEmpty { def += " DEFAULT \(dv)" }
        let sql = "ALTER TABLE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))` ADD COLUMN \(def)"
        try await runMutation(handle: handle, sql: sql)
    }

    func dropColumn(handle: String, table: TableID, column: String) async throws {
        let sql = "ALTER TABLE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))` DROP COLUMN `\(escapeIdentifier(column))`"
        try await runMutation(handle: handle, sql: sql)
    }

    func alterColumn(handle: String, table: TableID, column: String, newName: String?, newType: String?, nullable: Bool?, defaultValue: String?) async throws {
        if let name = newName {
            let sql = "ALTER TABLE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))` RENAME COLUMN `\(escapeIdentifier(column))` TO `\(escapeIdentifier(name))`"
            try await runMutation(handle: handle, sql: sql)
        }
        if let type = newType {
            let sql = "ALTER TABLE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))` MODIFY COLUMN `\(escapeIdentifier(column))` \(type)"
            try await runMutation(handle: handle, sql: sql)
        }
        if let nullable = nullable {
            let nullClause = nullable ? "NULL" : "NOT NULL"
            let sql = "ALTER TABLE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))` MODIFY COLUMN `\(escapeIdentifier(column))` \(nullClause)"
            try await runMutation(handle: handle, sql: sql)
        }
        if let dv = defaultValue {
            if dv.isEmpty || dv == "NULL" {
                let sql = "ALTER TABLE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))` ALTER COLUMN `\(escapeIdentifier(column))` DROP DEFAULT"
                try await runMutation(handle: handle, sql: sql)
            } else {
                let sql = "ALTER TABLE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))` ALTER COLUMN `\(escapeIdentifier(column))` SET DEFAULT \(dv)"
                try await runMutation(handle: handle, sql: sql)
            }
        }
    }

    func fetchIndexes(handle: String, table: TableID) async throws -> [IndexInfo] {
        let sql = "SHOW INDEX FROM `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))`"
        let rows = try await runQuery(handle: handle, sql: sql)
        var indexMap: [String: (cols: [String], unique: Bool)] = [:]
        for row in rows {
            guard let idxName = row[2], let colName = row[4], let nonUnique = row[1] else { continue }
            if indexMap[idxName] == nil {
                indexMap[idxName] = (cols: [], unique: nonUnique == "0")
            }
            indexMap[idxName]?.cols.append(colName)
        }
        return indexMap.map { name, info in
            IndexInfo(name: name, columns: info.cols, isUnique: info.unique, table: table.table, schema: table.schema)
        }
    }

    func createIndex(handle: String, table: TableID, name: String, columns: [String], unique: Bool) async throws {
        let uniqueSQL = unique ? "UNIQUE " : ""
        let colList = columns.map { "`\(escapeIdentifier($0))`" }.joined(separator: ", ")
        let sql = "CREATE \(uniqueSQL)INDEX `\(escapeIdentifier(name))` ON `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))` (\(colList))"
        try await runMutation(handle: handle, sql: sql)
    }

    func dropIndex(handle: String, indexName: String, table: TableID) async throws {
        let sql = "DROP INDEX `\(escapeIdentifier(indexName))` ON `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))`"
        try await runMutation(handle: handle, sql: sql)
    }

    func cancel(handle: String) async throws {
        let info = lock.withLock { (config: configs[handle], password: passwords[handle], connID: connectionIDs[handle]) }
        if let connID = info.connID {
            let tempConn = try await makeConnection(config: info.config!, password: info.password!)
            let tempHandle = UUID().uuidString
            lock.withLock { connections[tempHandle] = tempConn }
            defer {
                let c = lock.withLock { connections.removeValue(forKey: tempHandle) }
                Task { try? await c?.close().get() }
            }
            _ = try await runQuery(handle: tempHandle, sql: "KILL QUERY \(connID)")
        }
    }

    // MARK: - Helpers

    private func connection(for handle: String) throws -> MySQLConnection {
        lock.lock()
        defer { lock.unlock() }
        guard let conn = connections[handle] else { throw DatabaseError.notConnected }
        return conn
    }

    private func runQuery(handle: String, sql: String) async throws -> [[String?]] {
        let conn = try connection(for: handle)
        let rows = try await conn.simpleQuery(sql).get()
        return rows.map { mysqlRow in
            (0..<mysqlRow.columnDefinitions.count).map { i in
                decodeCell(mysqlRow, at: i)
            }
        }
    }

    private func decodeCell(_ row: MySQLRow, at index: Int) -> String? {
        guard index < row.values.count, let buffer = row.values[index] else { return nil }
        let data = MySQLData(
            type: row.columnDefinitions[index].columnType,
            format: row.format,
            buffer: buffer,
            isUnsigned: row.columnDefinitions[index].flags.contains(.COLUMN_UNSIGNED)
        )
        return data.string
    }

    @discardableResult
    private func runMutation(handle: String, sql: String) async throws -> Int {
        let conn = try connection(for: handle)
        _ = try await conn.simpleQuery(sql).get()
        return 0
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private func escapeIdentifier(_ ident: String) -> String {
        ident.replacingOccurrences(of: "`", with: "``")
    }

    private func escapeValue(_ value: String?) -> String {
        guard let value = value else { return "NULL" }
        let escaped = value.replacingOccurrences(of: "'", with: "''")
        return "'\(escaped)'"
    }
}
