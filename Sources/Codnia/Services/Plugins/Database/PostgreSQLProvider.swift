import Foundation
import Logging

@preconcurrency import PostgresNIO
import NIOPosix

final class PostgreSQLProvider: DatabaseProvider, @unchecked Sendable {
    let type: DatabaseType = .postgres

    private let eventLoopGroup: EventLoopGroup
    private var connections: [String: PostgresConnection] = [:]
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
        let conn = try await PostgresConnection.connect(
            on: eventLoopGroup.next(),
            configuration: pgConfig,
            id: 1,
            logger: logger
        )
        lock.lock()
        connections[handle] = conn
        lock.unlock()
        return handle
    }

    func close(handle: String) async throws {
        lock.lock()
        let conn = connections.removeValue(forKey: handle)
        lock.unlock()
        try await conn?.close()
    }

    func fetchDatabases(handle: String) async throws -> [DatabaseInfo] {
        let rows = try await runQuery(handle: handle, sql: "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname")
        let dbs = rows.map { DatabaseInfo(name: $0[0] ?? "?") }
        print("[PG] fetchDatabases → \(dbs.map(\.name))")
        return dbs
    }

    func fetchSchemas(handle: String) async throws -> [SchemaInfo] {
        let rows = try await runQuery(handle: handle, sql: "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast', 'pg_temp_1') AND schema_name NOT LIKE 'pg_toast_%' AND schema_name NOT LIKE 'pg_temp_%' ORDER BY schema_name")
        let schemas = rows.map { SchemaInfo(name: $0[0] ?? "?") }
        print("[PG] fetchSchemas → \(schemas.map(\.name))")
        return schemas
    }

    func fetchTables(handle: String, schema: String) async throws -> [TableInfo] {
        let sql = "SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = '\(escape(schema))' ORDER BY table_name"
        print("[PG] fetchTables SQL: \(sql)")
        let rows = try await runQuery(handle: handle, sql: sql)
        let tables = rows.map { row in
            let type: TableInfo.TableType = row[1] == "VIEW" ? .view : .table
            return TableInfo(schema: schema, name: row[0] ?? "?", tableType: type)
        }
        print("[PG] fetchTables('\(schema)') → \(tables.map { "\($0.name) (\($0.tableType))" })")
        return tables
    }

    func fetchColumns(handle: String, table: TableID) async throws -> [ColumnInfo] {
        let sql = """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = '\(escape(table.schema))' AND table_name = '\(escape(table.table))'
        ORDER BY ordinal_position
        """
        print("[PG] fetchColumns SQL: \(sql)")
        let rows = try await runQuery(handle: handle, sql: sql)
        let cols = rows.map { row in
            ColumnInfo(
                name: row[0] ?? "?",
                dataType: row[1] ?? "?",
                isNullable: row[2] == "YES",
                defaultValue: row[3]
            )
        }
        print("[PG] fetchColumns('\(table.schema).\(table.table)') → \(cols.map(\.name))")
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

    func execute(handle: String, query sql: String, page: Int, pageSize: Int, orderBy: String?) async throws -> QueryPageResult {
        let start = Date()
        let trimmed = sql
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ";"))
        let upper = trimmed.uppercased()

        guard upper.hasPrefix("SELECT") || upper.hasPrefix("WITH") || upper.hasPrefix("VALUES") || upper.hasPrefix("TABLE") else {
            let _ = try await runQuery(handle: handle, sql: trimmed)
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
        print("[PG] execute page=\(page) pageSize=\(pageSize) offset=\(offset) totalCount=\(totalCount)")
        print("[PG] pageSQL: \(pageSQL)")

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

        let elapsed = Date().timeIntervalSince(start)
        print("[PG] execute done: page=\(page) rows=\(rows.count) columns=\(columns)")
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
}

enum DatabaseError: LocalizedError {
    case notConnected

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to database"
        }
    }
}
