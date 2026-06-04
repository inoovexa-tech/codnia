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
        do {
            let rows = try await runQuery(handle: handle, sql: "SHOW DATABASES ORDER BY `Database`")
            return rows.map { DatabaseInfo(name: $0[0] ?? "?") }
        } catch {
            logger.error("fetchDatabases with ORDER BY failed: \(error.localizedDescription)")
            do {
                let rows = try await runQuery(handle: handle, sql: "SHOW DATABASES")
                return rows.map { DatabaseInfo(name: $0[0] ?? "?") }
            } catch {
                logger.error("fetchDatabases also failed without ORDER BY: \(error.localizedDescription)")
                throw error
            }
        }
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

    // MARK: - Identifier Quoting

    func quoteIdentifier(_ name: String) -> String {
        let escaped = name.replacingOccurrences(of: "`", with: "``")
        return "`\(escaped)`"
    }

    // MARK: - Triggers

    func fetchTriggers(handle: String, schema: String) async throws -> [TriggerInfo] {
        let sql = """
        SELECT TRIGGER_NAME, EVENT_OBJECT_TABLE, ACTION_TIMING, EVENT_MANIPULATION, ACTION_ORDER
        FROM INFORMATION_SCHEMA.TRIGGERS
        WHERE TRIGGER_SCHEMA = '\(escape(schema))'
        ORDER BY TRIGGER_NAME
        """
        let rows = try await runQuery(handle: handle, sql: sql)
        return rows.map { row in
            let table = row[1] ?? ""
            let timing = row[2] ?? ""
            let event = row[3] ?? ""
            let def = "\(timing) \(event) ON \(table)"
            return TriggerInfo(name: row[0] ?? "?", table: table, schema: schema, definition: def)
        }
    }

    func dropTrigger(handle: String, schema: String, trigger: String, table: String) async throws {
        let sql = "DROP TRIGGER IF EXISTS `\(escapeIdentifier(schema))`.`\(escapeIdentifier(trigger))`"
        try await runMutation(handle: handle, sql: sql)
    }

    // MARK: - Sequences (not native in MySQL, map to auto_increment info)

    func fetchSequences(handle: String, schema: String) async throws -> [SequenceInfo] {
        []
    }

    func dropSequence(handle: String, schema: String, sequence: String) async throws {
        throw DDLMethodError.notImplemented("dropSequence")
    }

    // MARK: - Constraints

    func fetchConstraints(handle: String, table: TableID) async throws -> [ConstraintInfo] {
        let sql = """
        SELECT tc.CONSTRAINT_NAME, tc.CONSTRAINT_TYPE,
               GROUP_CONCAT(kcu.COLUMN_NAME ORDER BY kcu.ORDINAL_POSITION SEPARATOR ',')
        FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
        JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
            ON tc.CONSTRAINT_SCHEMA = kcu.CONSTRAINT_SCHEMA
            AND tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
        WHERE tc.TABLE_SCHEMA = '\(escape(table.schema))'
            AND tc.TABLE_NAME = '\(escape(table.table))'
        GROUP BY tc.CONSTRAINT_NAME, tc.CONSTRAINT_TYPE
        ORDER BY tc.CONSTRAINT_TYPE, tc.CONSTRAINT_NAME
        """
        let rows = try await runQuery(handle: handle, sql: sql)
        return rows.compactMap { row in
            guard let name = row[0], let typeStr = row[1] else { return nil }
            let cols = (row[2] ?? "").split(separator: ",").map(String.init)
            let type: ConstraintInfo.ConstraintType
            switch typeStr {
            case "PRIMARY KEY": type = .primaryKey
            case "FOREIGN KEY": type = .foreignKey
            case "UNIQUE": type = .unique
            case "CHECK": type = .check
            default: return nil
            }
            return ConstraintInfo(name: name, type: type, table: table.table, schema: table.schema, columns: cols, definition: nil)
        }
    }

    func dropConstraint(handle: String, table: TableID, constraint: String) async throws {
        let sql = "ALTER TABLE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))` DROP CONSTRAINT `\(escapeIdentifier(constraint))`"
        try await runMutation(handle: handle, sql: sql)
    }

    func addForeignKey(handle: String, table: TableID, name: String, columns: [String], refTable: TableID, refColumns: [String], onDelete: String?, onUpdate: String?) async throws {
        let colList = columns.map { "`\(escapeIdentifier($0))`" }.joined(separator: ", ")
        let refColList = refColumns.map { "`\(escapeIdentifier($0))`" }.joined(separator: ", ")
        var options = ""
        if let od = onDelete { options += " ON DELETE \(od)" }
        if let ou = onUpdate { options += " ON UPDATE \(ou)" }
        let sql = """
        ALTER TABLE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))`
        ADD CONSTRAINT `\(escapeIdentifier(name))` FOREIGN KEY (\(colList))
        REFERENCES `\(escapeIdentifier(refTable.schema))`.`\(escapeIdentifier(refTable.table))` (\(refColList))\(options)
        """
        try await runMutation(handle: handle, sql: sql)
    }

    // MARK: - Table Properties

    func fetchTableStats(handle: String, table: TableID) async throws -> TableStats {
        let sql = """
        SELECT
            TABLE_ROWS,
            DATA_LENGTH + INDEX_LENGTH,
            DATA_LENGTH,
            INDEX_LENGTH,
            TABLE_COMMENT
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = '\(escape(table.schema))' AND TABLE_NAME = '\(escape(table.table))'
        """
        let rows = try await runQuery(handle: handle, sql: sql)
        guard let row = rows.first else { return TableStats() }
        let totalBytes = row[1].flatMap { Int($0) }
        let dataBytes = row[2].flatMap { Int($0) }
        let indexBytes = row[3].flatMap { Int($0) }
        return TableStats(
            estimatedRowCount: row[0].flatMap { Int($0) },
            exactRowCount: nil,
            totalSize: totalBytes.map { byteCountFormatted($0) },
            tableSize: dataBytes.map { byteCountFormatted($0) },
            indexSize: indexBytes.map { byteCountFormatted($0) },
            tableComment: row[4]
        )
    }

    private func byteCountFormatted(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    // MARK: - Routine Source

    func fetchRoutineSource(handle: String, schema: String, name: String, type: RoutineType) async throws -> String {
        let sql: String
        switch type {
        case .view:
            sql = "SHOW CREATE VIEW `\(escapeIdentifier(schema))`.`\(escapeIdentifier(name))`"
        case .function:
            sql = "SHOW CREATE FUNCTION `\(escapeIdentifier(schema))`.`\(escapeIdentifier(name))`"
        case .procedure:
            sql = "SHOW CREATE PROCEDURE `\(escapeIdentifier(schema))`.`\(escapeIdentifier(name))`"
        }
        let rows = try await runQuery(handle: handle, sql: sql)
        guard let row = rows.first, row.count > 1, let source = row[1] else {
            throw DDLMethodError.notImplemented("fetchRoutineSource")
        }
        return source
    }

    func updateRoutine(handle: String, schema: String, name: String, type: RoutineType, source: String) async throws {
        try await runMutation(handle: handle, sql: source)
    }

    // MARK: - Dependencies

    func fetchDependencies(handle: String, schema: String, table: String) async throws -> [String] {
        let sql = """
        SELECT DISTINCT REFERENCED_TABLE_SCHEMA || '.' || REFERENCED_TABLE_NAME
        FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
        WHERE TABLE_SCHEMA = '\(escape(schema))' AND TABLE_NAME = '\(escape(table))'
          AND REFERENCED_TABLE_NAME IS NOT NULL
        UNION
        SELECT DISTINCT TABLE_SCHEMA || '.' || TABLE_NAME
        FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
        WHERE REFERENCED_TABLE_SCHEMA = '\(escape(schema))' AND REFERENCED_TABLE_NAME = '\(escape(table))'
        """
        let rows = try await runQuery(handle: handle, sql: sql)
        return rows.compactMap { $0.first ?? nil }
    }

    // MARK: - Table Operations

    func renameTable(handle: String, table: TableID, newName: String) async throws {
        let sql = "RENAME TABLE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))` TO `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(newName))`"
        try await runMutation(handle: handle, sql: sql)
    }

    func moveTable(handle: String, table: TableID, newSchema: String) async throws {
        let sql = "RENAME TABLE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))` TO `\(escapeIdentifier(newSchema))`.`\(escapeIdentifier(table.table))`"
        try await runMutation(handle: handle, sql: sql)
    }

    func copyTable(handle: String, table: TableID, newName: String, copyData: Bool) async throws {
        let sql = "CREATE TABLE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(newName))` LIKE `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))`"
        try await runMutation(handle: handle, sql: sql)
        if copyData {
            let insertSQL = "INSERT INTO `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(newName))` SELECT * FROM `\(escapeIdentifier(table.schema))`.`\(escapeIdentifier(table.table))`"
            try await runMutation(handle: handle, sql: insertSQL)
        }
    }

    // MARK: - Transactions

    func beginTransaction(handle: String) async throws {
        try await runMutation(handle: handle, sql: "START TRANSACTION")
    }

    func commitTransaction(handle: String) async throws {
        try await runMutation(handle: handle, sql: "COMMIT")
    }

    func rollbackTransaction(handle: String) async throws {
        try await runMutation(handle: handle, sql: "ROLLBACK")
    }

    var supportsTransactions: Bool { true }

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
