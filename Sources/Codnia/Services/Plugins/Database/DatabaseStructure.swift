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
        case triggers = "Triggers"
        case sequences = "Sequences"
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

public struct TriggerInfo: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let table: String
    public let schema: String
    public let definition: String?

    public init(name: String, table: String, schema: String, definition: String?) {
        self.id = "\(schema).\(table).\(name)"
        self.name = name
        self.table = table
        self.schema = schema
        self.definition = definition
    }
}

public struct SequenceInfo: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let schema: String
    public let dataType: String?
    public let currentValue: Int?

    public init(name: String, schema: String, dataType: String?, currentValue: Int?) {
        self.id = "\(schema).\(name)"
        self.name = name
        self.schema = schema
        self.dataType = dataType
        self.currentValue = currentValue
    }
}

public struct ConstraintInfo: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let type: ConstraintType
    public let table: String
    public let schema: String
    public let columns: [String]
    public let definition: String?

    public enum ConstraintType: String, Sendable {
        case primaryKey = "PRIMARY KEY"
        case foreignKey = "FOREIGN KEY"
        case unique = "UNIQUE"
        case check = "CHECK"
        case exclude = "EXCLUDE"
    }

    public init(name: String, type: ConstraintType, table: String, schema: String, columns: [String], definition: String?) {
        self.id = "\(schema).\(table).\(name)"
        self.name = name
        self.type = type
        self.table = table
        self.schema = schema
        self.columns = columns
        self.definition = definition
    }
}

public struct TableStats: Sendable {
    public let estimatedRowCount: Int?
    public let exactRowCount: Int?
    public let totalSize: String?
    public let tableSize: String?
    public let indexSize: String?
    public let tableOwner: String?
    public let tableComment: String?
    public let lastVacuum: String?
    public let lastAnalyze: String?
    public let lastAutoVacuum: String?
    public let lastAutoAnalyze: String?

    public init(
        estimatedRowCount: Int? = nil,
        exactRowCount: Int? = nil,
        totalSize: String? = nil,
        tableSize: String? = nil,
        indexSize: String? = nil,
        tableOwner: String? = nil,
        tableComment: String? = nil,
        lastVacuum: String? = nil,
        lastAnalyze: String? = nil,
        lastAutoVacuum: String? = nil,
        lastAutoAnalyze: String? = nil
    ) {
        self.estimatedRowCount = estimatedRowCount
        self.exactRowCount = exactRowCount
        self.totalSize = totalSize
        self.tableSize = tableSize
        self.indexSize = indexSize
        self.tableOwner = tableOwner
        self.tableComment = tableComment
        self.lastVacuum = lastVacuum
        self.lastAnalyze = lastAnalyze
        self.lastAutoVacuum = lastAutoVacuum
        self.lastAutoAnalyze = lastAutoAnalyze
    }
}

public struct TableProperties: Sendable {
    public let table: TableInfo
    public let stats: TableStats?
    public let columns: [ColumnInfo]
    public let indexes: [IndexInfo]
    public let constraints: [ConstraintInfo]
    public let triggers: [TriggerInfo]
    public let dependencies: [String]
    public let ddl: String?
    public let primaryKeys: [String]

    public init(
        table: TableInfo,
        stats: TableStats? = nil,
        columns: [ColumnInfo],
        indexes: [IndexInfo],
        constraints: [ConstraintInfo],
        triggers: [TriggerInfo],
        dependencies: [String],
        ddl: String? = nil,
        primaryKeys: [String]
    ) {
        self.table = table
        self.stats = stats
        self.columns = columns
        self.indexes = indexes
        self.constraints = constraints
        self.triggers = triggers
        self.dependencies = dependencies
        self.ddl = ddl
        self.primaryKeys = primaryKeys
    }
}

public enum RoutineType: String, Sendable {
    case function = "FUNCTION"
    case procedure = "PROCEDURE"
    case view = "VIEW"
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

public struct TableGroup: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var name: String
    public var tableIds: [String]

    public init(id: String = UUID().uuidString, name: String, tableIds: [String] = []) {
        self.id = id
        self.name = name
        self.tableIds = tableIds
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
    case trigger(TriggerInfo)
    case sequence(SequenceInfo)
    case constraint(ConstraintInfo)
    case tableGroup(TableGroup, schema: String)

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
        case .trigger(let t): return "trig:\(t.id)"
        case .sequence(let s): return "seq:\(s.id)"
        case .constraint(let c): return "constr:\(c.id)"
        case .tableGroup(let g, _): return "group:\(g.id)"
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
        case .trigger(let t): return t.name
        case .sequence(let s): return s.name
        case .constraint(let c): return c.name
        case .tableGroup(let g, _): return g.name
        }
    }

    public var isExpandable: Bool {
        switch self {
        case .connection, .database, .schema, .schemaSection, .table, .tableGroup: return true
        case .column, .function, .procedure, .trigger, .sequence, .constraint: return false
        }
    }
}
