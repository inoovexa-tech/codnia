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
}
