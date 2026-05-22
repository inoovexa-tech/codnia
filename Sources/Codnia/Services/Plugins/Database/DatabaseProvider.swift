import Foundation

public protocol DatabaseProvider: AnyObject, Sendable {
    var type: DatabaseType { get }

    func open(config: ConnectionConfig, password: String) async throws -> String
    func close(handle: String) async throws
    func fetchDatabases(handle: String) async throws -> [DatabaseInfo]
    func fetchSchemas(handle: String) async throws -> [SchemaInfo]
    func fetchTables(handle: String, schema: String) async throws -> [TableInfo]
    func fetchColumns(handle: String, table: TableID) async throws -> [ColumnInfo]
    func fetchFunctions(handle: String, schema: String) async throws -> [FunctionInfo]
    func fetchProcedures(handle: String, schema: String) async throws -> [ProcedureInfo]
    func execute(handle: String, query: String, page: Int, pageSize: Int, orderBy: String?) async throws -> QueryPageResult

    // MARK: - DML

    func fetchPrimaryKeyColumns(handle: String, table: TableID) async throws -> [String]
    func updateRow(handle: String, table: TableID, set: [(column: String, value: String?)], primaryKeyValues: [(column: String, value: String?)]) async throws -> Int
    func insertRow(handle: String, table: TableID, columns: [String], values: [String?]) async throws -> [String: String?]?
    func deleteRow(handle: String, table: TableID, primaryKeyValues: [(column: String, value: String?)]) async throws -> Int

    // MARK: - DDL

    func fetchTableDDL(handle: String, table: TableID) async throws -> String
    func createTable(handle: String, schema: String, name: String, columns: [NewColumnInfo]) async throws
    func dropTable(handle: String, table: TableID, cascade: Bool) async throws
    func addColumn(handle: String, table: TableID, column: NewColumnInfo) async throws
    func dropColumn(handle: String, table: TableID, column: String) async throws
    func alterColumn(handle: String, table: TableID, column: String, newName: String?, newType: String?, nullable: Bool?, defaultValue: String?) async throws
    func fetchIndexes(handle: String, table: TableID) async throws -> [IndexInfo]
    func createIndex(handle: String, table: TableID, name: String, columns: [String], unique: Bool) async throws
    func dropIndex(handle: String, indexName: String, table: TableID) async throws

    // MARK: - Identifier Quoting

    func quoteIdentifier(_ name: String) -> String

    // MARK: - Cancellation

    func cancel(handle: String) async throws
    func setBackendPID(handle: String, pid: Int)
}

public struct NewColumnInfo: Sendable {
    public let name: String
    public let type: String
    public let isNullable: Bool
    public let defaultValue: String?
    public let isPrimaryKey: Bool

    public init(name: String, type: String, isNullable: Bool, defaultValue: String?, isPrimaryKey: Bool) {
        self.name = name
        self.type = type
        self.isNullable = isNullable
        self.defaultValue = defaultValue
        self.isPrimaryKey = isPrimaryKey
    }
}

public enum DDLMethodError: LocalizedError {
    case notImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .notImplemented(let method): return "DDL method not implemented for this provider: \(method)"
        }
    }
}
