import Foundation
import Combine

@MainActor
public final class DatabaseConnectionService: ObservableObject {
    @Published public var connections: [ConnectionConfig] = []
    @Published public var sessions: [String: SessionState] = [:]

    public private(set) var providers: [DatabaseType: any DatabaseProvider] = [:]

    private let fs = FileSystemService.shared
    private let connectionsFileName = "database-connections.json"
    private var connectionsLoaded = false

    public init() {
        registerProvider(PostgreSQLProvider())
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
        saveConnections()
    }

    public func connect(_ config: ConnectionConfig, password: String, database: String? = nil) async {
        sessions[config.id] = .connecting
        objectWillChange.send()

        guard let provider = providers[config.type] else {
            sessions[config.id] = .error("No provider for \(config.type)")
            objectWillChange.send()
            return
        }

        do {
            var effectiveConfig = config
            if let db = database { effectiveConfig.database = db }
            let handle = try await provider.open(config: effectiveConfig, password: password)
            sessions[config.id] = .connected(handleID: handle)
            KeychainHelper.save(account: config.id, password: password)
        } catch {
            sessions[config.id] = .error(error.localizedDescription)
        }
        objectWillChange.send()
    }

    public func disconnect(configID: String) async {
        guard case .connected(let handle) = sessions[configID],
              let config = config(withID: configID),
              let provider = providers[config.type]
        else {
            sessions[configID] = .disconnected
            objectWillChange.send()
            return
        }
        do {
            try await provider.close(handle: handle)
        } catch {
            
        }
        sessions[configID] = .disconnected
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

    // MARK: - Explain

    public func executeExplain(configID: String, sql: String) async -> QueryPageResult {
        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else {
            return QueryPageResult(
                columns: [], rows: [], totalCount: 0,
                page: 0, pageSize: 1,
                error: "Not connected"
            )
        }
        let explainSQL = "EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS, FORMAT JSON) \(sql)"
        do {
            return try await provider.execute(handle: handle, query: explainSQL, page: 0, pageSize: 1000, orderBy: nil)
        } catch {
            return QueryPageResult(
                columns: [], rows: [], totalCount: 0,
                page: 0, pageSize: 1,
                error: error.localizedDescription
            )
        }
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

    // MARK: - Schema Browsing

    public func fetchDatabases(configID: String) async -> [DatabaseInfo] {
        guard let config = config(withID: configID),
              let provider = providers[config.type],
              let handle = sessions[configID]?.handleID
        else { return [] }
        return (try? await provider.fetchDatabases(handle: handle)) ?? []
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
