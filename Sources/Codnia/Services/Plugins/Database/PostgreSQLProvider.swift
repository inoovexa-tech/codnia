import Foundation
import Logging

@preconcurrency import PostgresNIO
import NIOPosix

final class PostgreSQLProvider: DatabaseProvider, @unchecked Sendable {
    let type: DatabaseType = .postgres

    private let eventLoopGroup: EventLoopGroup
    private var connections: [String: PostgresConnection] = [:]
    private var configs: [String: ConnectionConfig] = [:]
    private var passwords: [String: String] = [:]
    private var backendPIDs: [String: Int] = [:]
    private let lock = NSLock()
    private let logger = Logger(label: "com.codnia.app.postgresql")

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
        let conn: PostgresConnection? = lock.withLock {
            let c = connections.removeValue(forKey: handle)
            configs.removeValue(forKey: handle)
            passwords.removeValue(forKey: handle)
            backendPIDs.removeValue(forKey: handle)
            return c
        }
        try await conn?.close()
    }

    func setBackendPID(handle: String, pid: Int) {
        lock.withLock { backendPIDs[handle] = pid }
    }

    private func makeConnection(config: ConnectionConfig, password: String) async throws -> PostgresConnection {
        let tls: PostgresConnection.Configuration.TLS = config.useSSL
            ? .require(try NIOSSLContext(configuration: .makeClientConfiguration()))
            : .disable
        let pgConfig = PostgresConnection.Configuration(
            host: config.host,
            port: config.port,
            username: config.user,
            password: password,
            database: config.database,
            tls: tls
        )
        return try await PostgresConnection.connect(
            on: eventLoopGroup.next(),
            configuration: pgConfig,
            id: 1,
            logger: logger
        )
    }

    func fetchDatabases(handle: String) async throws -> [DatabaseInfo] {
        let rows = try await runQuery(handle: handle, sql: "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname")
        let dbs = rows.map { DatabaseInfo(name: $0[0] ?? "?") }
        
        return dbs
    }

    func fetchSchemas(handle: String) async throws -> [SchemaInfo] {
        let rows = try await runQuery(handle: handle, sql: "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast', 'pg_temp_1') AND schema_name NOT LIKE 'pg_toast_%' AND schema_name NOT LIKE 'pg_temp_%' ORDER BY schema_name")
        let schemas = rows.map { SchemaInfo(name: $0[0] ?? "?") }
        
        return schemas
    }

    func fetchTables(handle: String, schema: String) async throws -> [TableInfo] {
        let sql = "SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = '\(escape(schema))' ORDER BY table_name"
        
        let rows = try await runQuery(handle: handle, sql: sql)
        let tables = rows.map { row in
            let type: TableInfo.TableType = row[1] == "VIEW" ? .view : .table
            return TableInfo(schema: schema, name: row[0] ?? "?", tableType: type)
        }
        
        return tables
    }

    func fetchColumns(handle: String, table: TableID) async throws -> [ColumnInfo] {
        let sql = """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = '\(escape(table.schema))' AND table_name = '\(escape(table.table))'
        ORDER BY ordinal_position
        """
        
        let rows = try await runQuery(handle: handle, sql: sql)
        let cols = rows.map { row in
            ColumnInfo(
                name: row[0] ?? "?",
                dataType: row[1] ?? "?",
                isNullable: row[2] == "YES",
                defaultValue: row[3]
            )
        }
        
        return cols
    }

    func fetchFunctions(handle: String, schema: String) async throws -> [FunctionInfo] {
        let sql = """
        SELECT routine_name, data_type
        FROM information_schema.routines
        WHERE specific_schema = '\(escape(schema))' AND routine_type = 'FUNCTION'
        ORDER BY routine_name
        """
        let rows = try await runQuery(handle: handle, sql: sql)
        return rows.map { FunctionInfo(name: $0[0] ?? "?", returnType: $0[1], schema: schema) }
    }

    func fetchProcedures(handle: String, schema: String) async throws -> [ProcedureInfo] {
        let sql = """
        SELECT routine_name
        FROM information_schema.routines
        WHERE specific_schema = '\(escape(schema))' AND routine_type = 'PROCEDURE'
        ORDER BY routine_name
        """
        let rows = try await runQuery(handle: handle, sql: sql)
        return rows.map { ProcedureInfo(name: $0[0] ?? "?", schema: schema) }
    }

    func cancel(handle: String) async throws {
        let info = lock.withLock { (configs: configs[handle], passwords: passwords[handle], pid: backendPIDs[handle]) }
        guard let config = info.configs, let password = info.passwords, let pid = info.pid else {
            return
        }
        let tempConn = try await makeConnection(config: config, password: password)
        let tempHandle = UUID().uuidString
        lock.withLock { connections[tempHandle] = tempConn }
        defer {
            let conn = lock.withLock { connections.removeValue(forKey: tempHandle) }
            Task { try? await conn?.close() }
        }
        _ = try await runQuery(handle: tempHandle, sql: "SELECT pg_cancel_backend(\(pid))")
    }

    func execute(handle: String, query sql: String, page: Int, pageSize: Int, orderBy: String?) async throws -> QueryPageResult {
        let start = Date()

        let pid = try await getBackendPID(handle: handle)
        lock.withLock { backendPIDs[handle] = pid }

        let trimmed = sql
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ";"))
        let upper = trimmed.uppercased()

        guard upper.hasPrefix("SELECT") || upper.hasPrefix("WITH") || upper.hasPrefix("VALUES") || upper.hasPrefix("TABLE") else {
            do {
                _ = try await runQuery(handle: handle, sql: trimmed)
            } catch {
                let _ = lock.withLock { backendPIDs.removeValue(forKey: handle) }
                throw error
            }
            let _ = lock.withLock { backendPIDs.removeValue(forKey: handle) }
            let elapsed = Date().timeIntervalSince(start)
            return QueryPageResult(
                columns: ["Result"],
                columnTypes: ["text"],
                rows: [["Query executed successfully"]],
                totalCount: 1,
                page: 0,
                pageSize: 1,
                executionTime: elapsed
            )
        }

        let countSQL = "SELECT COUNT(*) FROM (\(trimmed)) AS _cnt"
        let countRows: [[String?]]
        do {
            countRows = try await runQuery(handle: handle, sql: countSQL)
        } catch {
            let _ = lock.withLock { backendPIDs.removeValue(forKey: handle) }
            let elapsed = Date().timeIntervalSince(start)
            return QueryPageResult(
                columns: [],
                rows: [],
                totalCount: 0,
                page: page,
                pageSize: pageSize,
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
            let result = try await conn.query(PostgresQuery(unsafeSQL: pageSQL), logger: logger)
            var columnNames: [String] = []
            var isFirst = true
            for try await row in result {
                let access = row.makeRandomAccess()
                if isFirst {
                    columnNames = (0..<access.count).map { access[$0].columnName }
                    columns = columnNames
                    columnTypes = (0..<access.count).map { access[$0].dataType.description }
                    isFirst = false
                }
                var rowData: [String?] = []
                for i in 0..<columnNames.count {
                    rowData.append(decodeCell(access[i]))
                }
                rows.append(rowData)
            }
        } catch {
            let _ = lock.withLock { backendPIDs.removeValue(forKey: handle) }
            let elapsed = Date().timeIntervalSince(start)
            return QueryPageResult(
                columns: columns,
                columnTypes: columnTypes,
                rows: rows,
                totalCount: totalCount,
                page: page,
                pageSize: pageSize,
                executionTime: elapsed,
                error: error.localizedDescription
            )
        }

        let _ = lock.withLock { backendPIDs.removeValue(forKey: handle) }

        let elapsed = Date().timeIntervalSince(start)

        return QueryPageResult(
            columns: columns,
            columnTypes: columnTypes,
            rows: rows,
            totalCount: totalCount,
            page: page,
            pageSize: pageSize,
            executionTime: elapsed
        )
    }

    // MARK: - DDL

    func fetchTableDDL(handle: String, table: TableID) async throws -> String {
        let sql = """
        SELECT pg_catalog.pg_get_tabledef(
            '\(escape(table.schema))',
            '\(escape(table.table))'
        )
        """
        do {
            return try await runQuery(handle: handle, sql: sql)
                .compactMap { $0.first ?? nil }
                .joined(separator: "\n")
        } catch {
            let fallbackSQL = """
            SELECT column_name, data_type, is_nullable, column_default, ordinal_position
            FROM information_schema.columns
            WHERE table_schema = '\(escape(table.schema))' AND table_name = '\(escape(table.table))'
            ORDER BY ordinal_position
            """
            let cols = try await runQueryWithColumns(handle: handle, sql: fallbackSQL)
            var ddl = "CREATE TABLE \"\(escapeIdentifier(table.schema))\".\"\(escapeIdentifier(table.table))\" (\n"
            var colDefs: [String] = []
            for row in cols.rows {
                guard row.count >= 4 else { continue }
                let colName = row[0] ?? "?"
                let dataType = row[1] ?? "text"
                let nullable = row[2] == "YES"
                let defaultVal = row[3]
                var def = "    \"\(escapeIdentifier(colName))\" \(dataType)"
                if !nullable { def += " NOT NULL" }
                if let dv = defaultVal, !dv.isEmpty { def += " DEFAULT \(dv)" }
                colDefs.append(def)
            }

            let pkSQL = """
            SELECT kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
                AND tc.table_schema = kcu.table_schema
            WHERE tc.table_schema = '\(escape(table.schema))'
                AND tc.table_name = '\(escape(table.table))'
                AND tc.constraint_type = 'PRIMARY KEY'
            ORDER BY kcu.ordinal_position
            """
            let pkRows = try await runQuery(handle: handle, sql: pkSQL)
            let pkCols = pkRows.compactMap { $0.first ?? nil }
            if !pkCols.isEmpty {
                let pkList = pkCols.map { "\"\(escapeIdentifier($0))\"" }.joined(separator: ", ")
                colDefs.append("    PRIMARY KEY (\(pkList))")
            }

            ddl += colDefs.joined(separator: ",\n")
            ddl += "\n)"
            return ddl
        }
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

        let sql = "CREATE TABLE \"\(escapeIdentifier(schema))\".\"\(escapeIdentifier(name))\" (\n  \(colDefs.joined(separator: ",\n  "))\n)"
        try await runMutation(handle: handle, sql: sql)
    }

    func dropTable(handle: String, table: TableID, cascade: Bool) async throws {
        let cascadeSQL = cascade ? " CASCADE" : ""
        let sql = "DROP TABLE \"\(escapeIdentifier(table.schema))\".\"\(escapeIdentifier(table.table))\"\(cascadeSQL)"
        try await runMutation(handle: handle, sql: sql)
    }

    func addColumn(handle: String, table: TableID, column: NewColumnInfo) async throws {
        var def = "\"\(escapeIdentifier(column.name))\" \(column.type)"
        if !column.isNullable { def += " NOT NULL" }
        if let dv = column.defaultValue, !dv.isEmpty { def += " DEFAULT \(dv)" }
        let sql = "ALTER TABLE \"\(escapeIdentifier(table.schema))\".\"\(escapeIdentifier(table.table))\" ADD COLUMN \(def)"
        try await runMutation(handle: handle, sql: sql)
    }

    func dropColumn(handle: String, table: TableID, column: String) async throws {
        let sql = "ALTER TABLE \"\(escapeIdentifier(table.schema))\".\"\(escapeIdentifier(table.table))\" DROP COLUMN \"\(escapeIdentifier(column))\""
        try await runMutation(handle: handle, sql: sql)
    }

    func alterColumn(handle: String, table: TableID, column: String, newName: String?, newType: String?, nullable: Bool?, defaultValue: String?) async throws {
        if let name = newName {
            let sql = "ALTER TABLE \"\(escapeIdentifier(table.schema))\".\"\(escapeIdentifier(table.table))\" RENAME COLUMN \"\(escapeIdentifier(column))\" TO \"\(escapeIdentifier(name))\""
            try await runMutation(handle: handle, sql: sql)
        }
        if let type = newType {
            let sql = "ALTER TABLE \"\(escapeIdentifier(table.schema))\".\"\(escapeIdentifier(table.table))\" ALTER COLUMN \"\(escapeIdentifier(column))\" TYPE \(type)"
            try await runMutation(handle: handle, sql: sql)
        }
        if let nullable = nullable {
            if nullable {
                let sql = "ALTER TABLE \"\(escapeIdentifier(table.schema))\".\"\(escapeIdentifier(table.table))\" ALTER COLUMN \"\(escapeIdentifier(column))\" DROP NOT NULL"
                try await runMutation(handle: handle, sql: sql)
            } else {
                let sql = "ALTER TABLE \"\(escapeIdentifier(table.schema))\".\"\(escapeIdentifier(table.table))\" ALTER COLUMN \"\(escapeIdentifier(column))\" SET NOT NULL"
                try await runMutation(handle: handle, sql: sql)
            }
        }
        if let dv = defaultValue {
            if dv.isEmpty || dv == "NULL" {
                let sql = "ALTER TABLE \"\(escapeIdentifier(table.schema))\".\"\(escapeIdentifier(table.table))\" ALTER COLUMN \"\(escapeIdentifier(column))\" DROP DEFAULT"
                try await runMutation(handle: handle, sql: sql)
            } else {
                let sql = "ALTER TABLE \"\(escapeIdentifier(table.schema))\".\"\(escapeIdentifier(table.table))\" ALTER COLUMN \"\(escapeIdentifier(column))\" SET DEFAULT \(dv)"
                try await runMutation(handle: handle, sql: sql)
            }
        }
    }

    func fetchIndexes(handle: String, table: TableID) async throws -> [IndexInfo] {
        let sql = """
        SELECT indexname, indexdef
        FROM pg_indexes
        WHERE schemaname = '\(escape(table.schema))'
          AND tablename = '\(escape(table.table))'
        ORDER BY indexname
        """
        let rows = try await runQuery(handle: handle, sql: sql)
        return rows.map { row in
            let name = row[0] ?? "?"
            let def = row[1] ?? ""
            let isUnique = def.uppercased().contains("UNIQUE")
            let cols = parseIndexColumns(from: def)
            return IndexInfo(name: name, columns: cols, isUnique: isUnique, table: table.table, schema: table.schema)
        }
    }

    func createIndex(handle: String, table: TableID, name: String, columns: [String], unique: Bool) async throws {
        let uniqueSQL = unique ? "UNIQUE " : ""
        let colList = columns.map { "\"\(escapeIdentifier($0))\"" }.joined(separator: ", ")
        let sql = "CREATE \(uniqueSQL)INDEX \"\(escapeIdentifier(name))\" ON \"\(escapeIdentifier(table.schema))\".\"\(escapeIdentifier(table.table))\" (\(colList))"
        try await runMutation(handle: handle, sql: sql)
    }

    func dropIndex(handle: String, indexName: String, table: TableID) async throws {
        let sql = "DROP INDEX \"\(escapeIdentifier(table.schema))\".\"\(escapeIdentifier(indexName))\""
        try await runMutation(handle: handle, sql: sql)
    }

    private func parseIndexColumns(from def: String) -> [String] {
        guard let parenStart = def.lastIndex(of: "("),
              let parenEnd = def.lastIndex(of: ")"),
              parenStart < parenEnd else { return [] }
        let inner = def[def.index(after: parenStart)..<parenEnd]
        return inner
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "") }
    }

    // MARK: - DML

    func fetchPrimaryKeyColumns(handle: String, table: TableID) async throws -> [String] {
        let sql = """
        SELECT kcu.column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
        WHERE tc.table_schema = '\(escape(table.schema))'
            AND tc.table_name = '\(escape(table.table))'
            AND tc.constraint_type = 'PRIMARY KEY'
        ORDER BY kcu.ordinal_position
        """
        let rows = try await runQuery(handle: handle, sql: sql)
        return rows.compactMap { $0.first ?? nil }
    }

    func updateRow(handle: String, table: TableID, set: [(column: String, value: String?)], primaryKeyValues: [(column: String, value: String?)]) async throws -> Int {
        let setClause = set.map { "\"\(escapeIdentifier($0.column))\" = \(escapeValue($0.value))" }.joined(separator: ", ")
        let whereClause = primaryKeyValues.map { "\"\(escapeIdentifier($0.column))\" = \(escapeValue($0.value))" }.joined(separator: " AND ")
        let sql = "UPDATE \"\(escapeIdentifier(table.schema))\".\"\(escapeIdentifier(table.table))\" SET \(setClause) WHERE \(whereClause)"
        return try await runMutation(handle: handle, sql: sql)
    }

    func insertRow(handle: String, table: TableID, columns: [String], values: [String?]) async throws -> [String: String?]? {
        let colList = columns.map { "\"\(escapeIdentifier($0))\"" }.joined(separator: ", ")
        let valList = values.map { escapeValue($0) }.joined(separator: ", ")
        let sql = "INSERT INTO \"\(escapeIdentifier(table.schema))\".\"\(escapeIdentifier(table.table))\" (\(colList)) VALUES (\(valList)) RETURNING *"
        let result = try await runQueryWithColumns(handle: handle, sql: sql)
        guard let row = result.rows.first else { return nil }
        var dict: [String: String?] = [:]
        for (i, col) in result.columns.enumerated() {
            dict[col] = i < row.count ? row[i] : nil
        }
        return dict
    }

    func deleteRow(handle: String, table: TableID, primaryKeyValues: [(column: String, value: String?)]) async throws -> Int {
        let whereClause = primaryKeyValues.map { "\"\(escapeIdentifier($0.column))\" = \(escapeValue($0.value))" }.joined(separator: " AND ")
        let sql = "DELETE FROM \"\(escapeIdentifier(table.schema))\".\"\(escapeIdentifier(table.table))\" WHERE \(whereClause)"
        return try await runMutation(handle: handle, sql: sql)
    }

    private func getBackendPID(handle: String) async throws -> Int {
        let conn = try connection(for: handle)
        let result = try await conn.query("SELECT pg_backend_pid()", logger: logger)
        for try await row in result {
            let access = row.makeRandomAccess()
            return try access[0].decode(Int.self)
        }
        throw DatabaseError.notConnected
    }

    // MARK: - Identifier Quoting

    func quoteIdentifier(_ name: String) -> String {
        let escaped = name.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    // MARK: - Helpers

    private func connection(for handle: String) throws -> PostgresConnection {
        lock.lock()
        defer { lock.unlock() }
        guard let conn = connections[handle] else {
            throw DatabaseError.notConnected
        }
        return conn
    }

    private func runQuery(handle: String, sql: String) async throws -> [[String?]] {
        let conn = try connection(for: handle)
        let result = try await conn.query(PostgresQuery(unsafeSQL: sql), logger: logger)
        var rows: [[String?]] = []
        for try await row in result {
            let access = row.makeRandomAccess()
            var rowData: [String?] = []
            for i in 0..<access.count {
                rowData.append(decodeCell(access[i]))
            }
            rows.append(rowData)
        }
        return rows
    }

    private func runQueryWithColumns(handle: String, sql: String) async throws -> (columns: [String], columnTypes: [String], rows: [[String?]]) {
        let conn = try connection(for: handle)
        let result = try await conn.query(PostgresQuery(unsafeSQL: sql), logger: logger)
        var columns: [String] = []
        var columnTypes: [String] = []
        var rows: [[String?]] = []
        var isFirst = true
        for try await row in result {
            let access = row.makeRandomAccess()
            if isFirst {
                columns = (0..<access.count).map { access[$0].columnName }
                columnTypes = (0..<access.count).map { access[$0].dataType.description }
                isFirst = false
            }
            var rowData: [String?] = []
            for i in 0..<columns.count {
                rowData.append(decodeCell(access[i]))
            }
            rows.append(rowData)
        }
        return (columns, columnTypes, rows)
    }

    @discardableResult
    private func runMutation(handle: String, sql: String) async throws -> Int {
        let conn = try connection(for: handle)
        let result = try await conn.query(PostgresQuery(unsafeSQL: sql), logger: logger)
        var affected = 0
        for try await row in result {
            let access = row.makeRandomAccess()
            if access.count > 0, let tag = try? access[0].decode(String.self) {
                if tag.hasPrefix("INSERT") || tag.hasPrefix("UPDATE") || tag.hasPrefix("DELETE") {
                    let parts = tag.split(separator: " ")
                    if let count = Int(parts.last ?? "") {
                        affected = count
                    }
                }
            }
        }
        return affected
    }

    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func decodeCell(_ cell: PostgresCell) -> String? {
        guard cell.bytes != nil else { return nil }
        if let int = try? cell.decode(Int.self) {
            return String(int)
        }
        if let int = try? cell.decode(Int64.self) {
            return String(int)
        }
        if let int = try? cell.decode(Int32.self) {
            return String(int)
        }
        if let int = try? cell.decode(Int16.self) {
            return String(int)
        }
        if let dbl = try? cell.decode(Double.self) {
            return String(dbl)
        }
        if let flt = try? cell.decode(Float.self) {
            return String(flt)
        }
        if let bool = try? cell.decode(Bool.self) {
            return bool ? "true" : "false"
        }
        if let date = try? cell.decode(Date.self) {
            return dateFormatter.string(from: date)
        }
        if let uuid = try? cell.decode(UUID.self) {
            return uuid.uuidString
        }
        if let decimal = try? cell.decode(Decimal.self) {
            return (decimal as NSDecimalNumber).stringValue
        }
        if let string = try? cell.decode(String.self) {
            return string
        }
        if let data = try? cell.decode(Data.self) {
            return "0x" + data.map { String(format: "%02x", $0) }.joined()
        }
        return "<\(cell.dataType.description)>"
    }

    private func escape(_ ident: String) -> String {
        ident.replacingOccurrences(of: "'", with: "''")
    }

    private func escapeIdentifier(_ ident: String) -> String {
        ident.replacingOccurrences(of: "\"", with: "\"\"")
    }

    private func escapeValue(_ value: String?) -> String {
        guard let value = value else { return "NULL" }
        let escaped = value.replacingOccurrences(of: "'", with: "''")
        return "'\(escaped)'"
    }
}

enum DatabaseError: LocalizedError {
    case notConnected

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to database"
        }
    }
}
