import Foundation
import Combine

@MainActor
public final class DatabaseConnectionService: ObservableObject {
    @Published public var connections: [ConnectionConfig] = []
    @Published public var sessions: [String: SessionState] = [:]
    @Published public var activeDatabases: [String: String] = [:]

    public private(set) var providers: [DatabaseType: any DatabaseProvider] = [:]

    private let fs = FileSystemService.shared
    private let connectionsFileName = "database-connections.json"
    private var connectionsLoaded = false

    public let sshTunnelService = SSHTunnelService()

    @Published public var schemaVersion: Int = 0
    @Published public var fetchErrors: [String: String] = [:]

    public init() {
        registerProvider(PostgreSQLProvider())
        registerProvider(MySQLProvider())
        registerProvider(SQLiteProvider())
    }

    private func ensureConnectionsLoaded() {
        guard !connectionsLoaded else { return }
        connectionsLoaded = true
        loadConnections()
    }

    // MARK: - Provider Registry

    public func registerProvider(_ provider: any DatabaseProvider) {
        providers[provider.type] = provider
    }

    // MARK: - Connection Management

    public var hasConnections: Bool {
        ensureConnectionsLoaded()
        return !connections.isEmpty
    }

    public func config(withID id: String) -> ConnectionConfig? {
        ensureConnectionsLoaded()
        return connections.first { $0.id == id }
    }

    public func state(for configID: String) -> SessionState {
        sessions[configID] ?? .disconnected
    }

    public func addConnection(_ config: ConnectionConfig) {
        ensureConnectionsLoaded()
        if let idx = connections.firstIndex(where: { $0.id == config.id }) {
            connections[idx] = config
        } else {
            connections.append(config)
        }
        saveConnections()
    }

    public func removeConnection(_ config: ConnectionConfig) {
        if sessions[config.id]?.isConnected == true {
            Task { await disconnect(configID: config.id) }
        }
        connections.removeAll { $0.id == config.id }
        sessions.removeValue(forKey: config.id)
        KeychainHelper.delete(account: config.id)
        sshTunnelService.stopTunnel(configID: config.id)
        saveConnections()
    }

    public func connect(_ config: ConnectionConfig, password: String, database: String? = nil) async {
        sessions[config.id] = .connecting
        fetchErrors[config.id] = nil
        objectWillChange.send()

        guard let provider = providers[config.type] else {
            sessions[config.id] = .error("No provider for \(config.type)")
            objectWillChange.send()
            return
        }

        do {
            var effectiveConfig = config
            if let db = database { effectiveConfig.database = db }

            if let sshConfig = config.sshConfig, sshConfig.host.isEmpty == false {
                let localPort = try await sshTunnelService.startTunnel(
                    configID: config.id,
                    sshConfig: sshConfig,
                    remoteHost: config.host,
                    remotePort: config.port
                )
                effectiveConfig.host = "127.0.0.1"
                effectiveConfig.port = localPort
            }

            let handle = try await provider.open(config: effectiveConfig, password: password)
            sessions[config.id] = .connected(handleID: handle)
            activeDatabases[config.id] = effectiveConfig.database
            KeychainHelper.save(account: config.id, password: password)
        } catch {
            sshTunnelService.stopTunnel(configID: config.id)
            sessions[config.id] = .error(error.localizedDescription)
        }
        objectWillChange.send()
    }

    public func disconnect(configID: String) async {
        if case .connected(let handle) = sessions[configID],
              let config = config(withID: configID),
              let provider = providers[config.type] {
            do {
                try await provider.close(handle: handle)
            } catch {

            }
        }
        sshTunnelService.stopTunnel(configID: configID)
        sessions[configID] = .disconnected
        activeDatabases[configID] = nil
        fetchErrors[configID] = nil
        objectWillChange.send()
    }

    public func password(for configID: String) -> String? {
        KeychainHelper.get(account: configID)
    }

    // MARK: - Cancel Execution

    public func cancelExecution(configID: String) async {
        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else { return }
        try? await provider.cancel(handle: handle)
    }

    public func setBackendPID(configID: String, pid: Int) {
        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else { return }
        provider.setBackendPID(handle: handle, pid: pid)
    }

    // MARK: - Query Execution

    public func execute(configID: String, sql: String, page: Int = 0, pageSize: Int = 100, orderBy: String? = nil) async -> QueryPageResult {

        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else {
            return QueryPageResult(
                columns: [], rows: [], totalCount: 0,
                page: page, pageSize: pageSize,
                error: "Not connected"
            )
        }
        do {
            let result = try await provider.execute(handle: handle, query: sql, page: page, pageSize: pageSize, orderBy: orderBy)

            return result
        } catch {
            return QueryPageResult(
                columns: [], rows: [], totalCount: 0,
                page: page, pageSize: pageSize,
                error: error.localizedDescription
            )
        }
    }

    // MARK: - DML Operations

    public func fetchPrimaryKeyColumns(configID: String, table: TableID) async -> [String] {
        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else { return [] }
        return (try? await provider.fetchPrimaryKeyColumns(handle: handle, table: table)) ?? []
    }

    public func updateRow(configID: String, table: TableID, set: [(column: String, value: String?)], primaryKeyValues: [(column: String, value: String?)]) async -> Int {
        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else { return 0 }
        return (try? await provider.updateRow(handle: handle, table: table, set: set, primaryKeyValues: primaryKeyValues)) ?? 0
    }

    public func insertRow(configID: String, table: TableID, columns: [String], values: [String?]) async throws -> [String: String?]? {
        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else { return nil }
        return try await provider.insertRow(handle: handle, table: table, columns: columns, values: values)
    }

    public func deleteRow(configID: String, table: TableID, primaryKeyValues: [(column: String, value: String?)]) async -> Int {
        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else { return 0 }
        return (try? await provider.deleteRow(handle: handle, table: table, primaryKeyValues: primaryKeyValues)) ?? 0
    }

    // MARK: - DDL Operations

    private func ddlProvider(for configID: String) -> (any DatabaseProvider, String)? {
        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else { return nil }
        return (provider, handle)
    }

    public func fetchTableDDL(configID: String, table: TableID) async -> String {
        guard let (provider, handle) = ddlProvider(for: configID) else { return "" }
        return (try? await provider.fetchTableDDL(handle: handle, table: table)) ?? ""
    }

    public func createTable(configID: String, schema: String, name: String, columns: [NewColumnInfo]) async throws {
        guard let (provider, handle) = ddlProvider(for: configID) else { throw DatabaseConnectionError.notConnected }
        try await provider.createTable(handle: handle, schema: schema, name: name, columns: columns)
        schemaVersion += 1
    }

    public func dropTable(configID: String, table: TableID, cascade: Bool) async throws {
        guard let (provider, handle) = ddlProvider(for: configID) else { throw DatabaseConnectionError.notConnected }
        try await provider.dropTable(handle: handle, table: table, cascade: cascade)
        schemaVersion += 1
    }

    public func addColumn(configID: String, table: TableID, column: NewColumnInfo) async throws {
        guard let (provider, handle) = ddlProvider(for: configID) else { throw DatabaseConnectionError.notConnected }
        try await provider.addColumn(handle: handle, table: table, column: column)
        schemaVersion += 1
    }

    public func dropColumn(configID: String, table: TableID, column: String) async throws {
        guard let (provider, handle) = ddlProvider(for: configID) else { throw DatabaseConnectionError.notConnected }
        try await provider.dropColumn(handle: handle, table: table, column: column)
        schemaVersion += 1
    }

    public func alterColumn(configID: String, table: TableID, column: String, newName: String? = nil, newType: String? = nil, nullable: Bool? = nil, defaultValue: String? = nil) async throws {
        guard let (provider, handle) = ddlProvider(for: configID) else { throw DatabaseConnectionError.notConnected }
        try await provider.alterColumn(handle: handle, table: table, column: column, newName: newName, newType: newType, nullable: nullable, defaultValue: defaultValue)
        schemaVersion += 1
    }

    public func fetchIndexes(configID: String, table: TableID) async -> [IndexInfo] {
        guard let (provider, handle) = ddlProvider(for: configID) else { return [] }
        return (try? await provider.fetchIndexes(handle: handle, table: table)) ?? []
    }

    public func createIndex(configID: String, table: TableID, name: String, columns: [String], unique: Bool) async throws {
        guard let (provider, handle) = ddlProvider(for: configID) else { throw DatabaseConnectionError.notConnected }
        try await provider.createIndex(handle: handle, table: table, name: name, columns: columns, unique: unique)
        schemaVersion += 1
    }

    public func dropIndex(configID: String, indexName: String, table: TableID) async throws {
        guard let (provider, handle) = ddlProvider(for: configID) else { throw DatabaseConnectionError.notConnected }
        try await provider.dropIndex(handle: handle, indexName: indexName, table: table)
        schemaVersion += 1
    }

    // MARK: - Schema Browsing

    public func fetchDatabases(configID: String) async -> [DatabaseInfo] {
        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else { return [] }
        do {
            let result = try await provider.fetchDatabases(handle: handle)
            fetchErrors[configID] = nil
            return result
        } catch {
            fetchErrors[configID] = error.localizedDescription
            return []
        }
    }

    public func fetchSchemas(configID: String) async -> [SchemaInfo] {
        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else { return [] }
        return (try? await provider.fetchSchemas(handle: handle)) ?? []
    }

    public func fetchTables(configID: String, schema: String) async -> [TableInfo] {
        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else { return [] }
        return (try? await provider.fetchTables(handle: handle, schema: schema)) ?? []
    }

    public func fetchColumns(configID: String, table: TableID) async -> [ColumnInfo] {
        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else { return [] }
        return (try? await provider.fetchColumns(handle: handle, table: table)) ?? []
    }

    public func fetchFunctions(configID: String, schema: String) async -> [FunctionInfo] {
        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else { return [] }
        return (try? await provider.fetchFunctions(handle: handle, schema: schema)) ?? []
    }

    public func fetchProcedures(configID: String, schema: String) async -> [ProcedureInfo] {
        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else { return [] }
        return (try? await provider.fetchProcedures(handle: handle, schema: schema)) ?? []
    }

    // MARK: - Foreign Keys (for ER Diagram)

    public func fetchForeignKeys(configID: String, schema: String) async -> [ForeignKeyInfo] {
        guard let config = config(withID: configID),
              sessions[configID]?.isConnected == true
        else { return [] }

        var sql: String
        switch config.type {
        case .postgres:
            sql = """
            SELECT
                tc.constraint_name,
                kcu.table_schema AS schema_name,
                kcu.table_name AS table_name,
                kcu.column_name AS column_name,
                ccu.table_schema AS foreign_schema_name,
                ccu.table_name AS foreign_table_name,
                ccu.column_name AS foreign_column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_catalog = kcu.constraint_catalog
                AND tc.constraint_schema = kcu.constraint_schema
                AND tc.constraint_name = kcu.constraint_name
            JOIN information_schema.constraint_column_usage ccu
                ON ccu.constraint_catalog = tc.constraint_catalog
                AND ccu.constraint_schema = tc.constraint_schema
                AND ccu.constraint_name = tc.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY'
                AND kcu.table_schema = '\(schema)'
            """
        case .mysql:
            sql = """
            SELECT
                tc.constraint_name,
                tc.table_schema AS schema_name,
                tc.table_name AS table_name,
                kcu.column_name AS column_name,
                kcu.referenced_table_schema AS foreign_schema_name,
                kcu.referenced_table_name AS foreign_table_name,
                kcu.referenced_column_name AS foreign_column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_schema = kcu.constraint_schema
                AND tc.constraint_name = kcu.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY'
                AND tc.table_schema = '\(schema)'
            """
        case .sqlite:
            return []
        }

        let result = await execute(configID: configID, sql: sql, pageSize: 1000)
        if result.error != nil {
            return []
        }

        var fks: [ForeignKeyInfo] = []
        let colIdx = { (name: String) -> Int? in
            result.columns.firstIndex { $0.lowercased() == name.lowercased() }
        }

        for row in result.rows {
            guard let constraintNameIdx = colIdx("constraint_name"),
                  let schemaIdx = colIdx("schema_name"),
                  let tableIdx = colIdx("table_name"),
                  let columnIdx = colIdx("column_name"),
                  let foreignSchemaIdx = colIdx("foreign_schema_name"),
                  let foreignTableIdx = colIdx("foreign_table_name"),
                  let foreignColumnIdx = colIdx("foreign_column_name")
            else { continue }

            let info = ForeignKeyInfo(
                constraintName: row[constraintNameIdx] ?? "",
                schema: row[schemaIdx] ?? schema,
                table: row[tableIdx] ?? "",
                column: row[columnIdx] ?? "",
                foreignSchema: row[foreignSchemaIdx] ?? "",
                foreignTable: row[foreignTableIdx] ?? "",
                foreignColumn: row[foreignColumnIdx] ?? ""
            )
            fks.append(info)
        }
        return fks
    }

    // MARK: - Identifier Quoting

    public func quoteIdentifier(configID: String, _ name: String) -> String? {
        guard let config = config(withID: configID),
              let provider = providers[config.type]
        else { return nil }
        return provider.quoteIdentifier(name)
    }

    // MARK: - Row Count

    public func fetchRowCount(configID: String, schema: String, table: String) async -> Int {
        guard sessions[configID]?.isConnected == true else { return 0 }
        guard let qSchema = quoteIdentifier(configID: configID, schema),
              let qTable = quoteIdentifier(configID: configID, table)
        else { return 0 }
        let sql = "SELECT COUNT(*) AS cnt FROM \(qSchema).\(qTable)"
        let result = await execute(configID: configID, sql: sql, pageSize: 1)
        if result.error != nil { return 0 }
        guard let firstRow = result.rows.first, let countStr = firstRow.first else { return 0 }
        return Int(countStr ?? "0") ?? 0
    }

    // MARK: - Persistence

    private func connectionsFileURL() -> URL? {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return appSupport.appendingPathComponent("Codnia").appendingPathComponent(connectionsFileName)
    }

    private func loadConnections() {
        guard let url = connectionsFileURL(),
              let data = try? Data(contentsOf: url),
              let configs = try? JSONDecoder().decode([ConnectionConfig].self, from: data)
        else { return }
        connections = configs
    }

    private func saveConnections() {
        guard let url = connectionsFileURL(),
              let data = try? JSONEncoder().encode(connections)
        else { return }
        try? data.write(to: url)
    }
}

public enum DatabaseConnectionError: LocalizedError {
    case notConnected
    case providerNotFound

    public var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to database"
        case .providerNotFound: return "No provider found for database type"
        }
    }
}

// MARK: - Foreign Key Model

public struct ForeignKeyInfo: Identifiable, Sendable {
    public let id: String
    public let constraintName: String
    public let schema: String
    public let table: String
    public let column: String
    public let foreignSchema: String
    public let foreignTable: String
    public let foreignColumn: String

    public init(constraintName: String, schema: String, table: String, column: String, foreignSchema: String, foreignTable: String, foreignColumn: String) {
        self.id = "\(schema).\(table).\(constraintName)"
        self.constraintName = constraintName
        self.schema = schema
        self.table = table
        self.column = column
        self.foreignSchema = foreignSchema
        self.foreignTable = foreignTable
        self.foreignColumn = foreignColumn
    }
}
