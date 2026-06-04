import Foundation

public struct DatabaseInfo: Identifiable, Sendable {
    public let id: String
    public let name: String

    public init(name: String) {
        self.id = name
        self.name = name
    }
}

public struct SchemaInfo: Identifiable, Sendable {
    public let id: String
    public let name: String

    public init(name: String) {
        self.id = name
        self.name = name
    }
}

public struct SchemaSection: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let schema: String
    public let sectionType: SchemaSectionType

    public enum SchemaSectionType: String, Sendable, CaseIterable {
        case tables = "Tables"
        case views = "Views"
        case materializedViews = "Materialized Views"
        case functions = "Functions"
        case procedures = "Procedures"
    }

    public init(sectionType: SchemaSectionType, schema: String) {
        self.id = "\(schema).\(sectionType.rawValue)"
        self.name = sectionType.rawValue
        self.schema = schema
        self.sectionType = sectionType
    }
}

public struct TableInfo: Identifiable, Sendable {
    public let id: String
    public let schema: String
    public let name: String
    public let tableType: TableType

    public enum TableType: String, Sendable {
        case table = "BASE TABLE"
        case view = "VIEW"
        case materializedView = "MATERIALIZED VIEW"
    }

    public init(schema: String, name: String, tableType: TableType = .table) {
        self.id = "\(schema).\(name)"
        self.schema = schema
        self.name = name
        self.tableType = tableType
    }
}

public struct ColumnInfo: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let dataType: String
    public let isNullable: Bool
    public let defaultValue: String?

    public init(name: String, dataType: String, isNullable: Bool, defaultValue: String?) {
        self.id = name
        self.name = name
        self.dataType = dataType
        self.isNullable = isNullable
        self.defaultValue = defaultValue
    }
}

public struct FunctionInfo: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let returnType: String?
    public let schema: String

    public init(name: String, returnType: String?, schema: String) {
        self.id = "\(schema).\(name)"
        self.name = name
        self.returnType = returnType
        self.schema = schema
    }
}

public struct ProcedureInfo: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let schema: String

    public init(name: String, schema: String) {
        self.id = "\(schema).\(name)"
        self.name = name
        self.schema = schema
    }
}

public struct TableID: Sendable {
    public let schema: String
    public let table: String

    public init(schema: String, table: String) {
        self.schema = schema
        self.table = table
    }
}

public struct IndexInfo: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let columns: [String]
    public let isUnique: Bool
    public let table: String
    public let schema: String

    public init(name: String, columns: [String], isUnique: Bool, table: String, schema: String) {
        self.id = "\(schema).\(table).\(name)"
        self.name = name
        self.columns = columns
        self.isUnique = isUnique
        self.table = table
        self.schema = schema
    }
}

public enum DBTreeEntry: Identifiable, Sendable {
    case connection(ConnectionConfig, state: SessionState)
    case database(String)
    case schema(SchemaInfo)
    case schemaSection(SchemaSection)
    case table(TableInfo)
    case column(ColumnInfo, tableName: String)
    case function(FunctionInfo)
    case procedure(ProcedureInfo)

    public var id: String {
        switch self {
        case .connection(let c, _): return "conn:\(c.id)"
        case .database(let n): return "db:\(n)"
        case .schema(let s): return "schema:\(s.id)"
        case .schemaSection(let sec): return sec.id
        case .table(let t): return "table:\(t.id)"
        case .column(let c, let t): return "col:\(t).\(c.id)"
        case .function(let f): return "func:\(f.id)"
        case .procedure(let p): return "proc:\(p.id)"
        }
    }

    public var name: String {
        switch self {
        case .connection(let c, _): return c.name
        case .database(let n): return n
        case .schema(let s): return s.name
        case .schemaSection(let sec): return sec.name
        case .table(let t): return t.name
        case .column(let c, _): return c.name
        case .function(let f): return f.name
        case .procedure(let p): return p.name
        }
    }

    public var isExpandable: Bool {
        switch self {
        case .connection, .database, .schema, .schemaSection, .table: return true
        case .column, .function, .procedure: return false
        }
    }
}
