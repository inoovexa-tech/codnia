import SwiftUI

struct DatabaseExplorerView: View {
    @EnvironmentObject var databaseService: DatabaseConnectionService
    @EnvironmentObject var editorVM: EditorViewModel

    @State private var expandedItems = Set<String>()
    @State private var loadingItems = Set<String>()
    @State private var cachedChildren: [String: [DBTreeEntry]] = [:]
    @State private var showConnectionSheet = false
    @State private var connectionToEdit: ConnectionConfig?
    @State private var hoveredId: String?
    @State private var showCreateTable = false
    @State private var createTableConfigID = ""
    @State private var createTableSchema = ""
    @State private var showAlterColumn = false
    @State private var alterColumnConfigID = ""
    @State private var alterColumnTable = TableID(schema: "", table: "")
    @State private var alterColumnInfo: ColumnInfo?
    @State private var alterColumnMode: AlterColumnSheet.AlterMode = .add
    @State private var showIndexManagement = false
    @State private var indexManagementConfigID = ""
    @State private var indexManagementTable = TableID(schema: "", table: "")
    @State private var showDropAlert = false
    @State private var dropConfigID = ""
    @State private var dropTarget = ""
    @State private var dropType = ""
    @State private var dropTableID = TableID(schema: "", table: "")
    @State private var dropCascade = false
    @State private var dropErrorMessage: String?
    @State private var searchText = ""
    @State private var rowCounts: [String: Int] = [:]
    @State private var loadingRowCounts = Set<String>()

    var body: some View {
        VStack(spacing: 0) {
            header

            searchBar

            if databaseService.connections.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 2) {
                        let grouped = groupedConnections
                        if grouped.isEmpty {
                            ForEach(databaseService.connections) { config in
                                connectionRow(config)
                            }
                        } else {
                            ForEach(Array(grouped.keys.sorted()).filter { $0 != "__ungrouped" }, id: \.self) { groupName in
                                if let conns = grouped[groupName] {
                                    groupSection(groupName, connections: conns)
                                }
                            }
                            if let ungrouped = grouped["__ungrouped"], !ungrouped.isEmpty {
                                groupSection("Ungrouped", connections: ungrouped)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    savedQueriesSection
                }
            }
        }
        .sheet(isPresented: $showConnectionSheet) {
            ConnectionEditSheet()
                .environmentObject(databaseService)
        }
        .sheet(item: $connectionToEdit) { config in
            ConnectionEditSheet(editingConfig: config)
                .environmentObject(databaseService)
        }
        .sheet(isPresented: $showCreateTable) {
            CreateTableSheet(configID: createTableConfigID, schema: createTableSchema)
                .environmentObject(databaseService)
        }
        .sheet(isPresented: $showAlterColumn) {
            AlterColumnSheet(
                configID: alterColumnConfigID,
                table: alterColumnTable,
                column: alterColumnInfo,
                mode: alterColumnMode
            )
            .environmentObject(databaseService)
        }
        .sheet(isPresented: $showIndexManagement) {
            IndexManagementView(configID: indexManagementConfigID, table: indexManagementTable)
                .environmentObject(databaseService)
        }
        .alert("Drop \(dropType)", isPresented: $showDropAlert, actions: {
            if dropType == "Table" {
                Toggle("CASCADE (drop dependent objects)", isOn: $dropCascade)
                    .toggleStyle(.checkbox)
            }
            Button("Cancel", role: .cancel) {
                dropCascade = false
                dropErrorMessage = nil
            }
            Button("Drop", role: .destructive) {
                performDrop()
            }
        }, message: {
            Text("Are you sure you want to drop \(dropType.lowercased()) \"\(dropTarget)\"?")
            if let error = dropErrorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        })
        .onChange(of: databaseService.schemaVersion) { _ in
            refreshAllCaches()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 4) {
            Text("DATABASES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textTertiary)

            Spacer()

            Button(action: { showConnectionSheet = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
            .frame(width: 20, height: 20)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
            TextField("Filter tables...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.textPrimary)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.bgTertiary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Groups

    private var groupedConnections: [String: [ConnectionConfig]] {
        let groups = Dictionary(grouping: databaseService.connections) { config in
            config.group ?? "__ungrouped"
        }
        return groups
    }

    private func groupSection(_ name: String, connections: [ConnectionConfig]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
                Text(name == "__ungrouped" ? "Ungrouped" : name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.textTertiary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            ForEach(connections) { config in
                connectionRow(config)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: "server.rack")
                .font(.system(size: 36))
                .foregroundColor(.textTertiary)

            Text("No connections")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)

            Text("Add a database connection\nto get started")
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)

            Button("Add Connection") {
                showConnectionSheet = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Connection Row

    private func connectionRow(_ config: ConnectionConfig) -> some View {
        let state = databaseService.state(for: config.id)
        let connId = "conn:\(config.id)"

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Button(action: { toggleConnection(config) }) {
                    Image(systemName: expandedItems.contains(connId) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 16, height: 16)

                Circle()
                    .fill(connectionDotColor(for: state))
                    .frame(width: 6, height: 6)

                Image(systemName: config.type == .postgres ? "elephant" : "server.rack")
                    .font(.system(size: 12))
                    .foregroundColor(.accentBlue)

                Text(config.name)
                    .font(.system(size: 13))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                if let env = config.environment, !env.isEmpty {
                    environmentBadge(env)
                }

                Spacer()

                if case .connecting = state {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                } else if state.isConnected {
                    Button(action: {
                        editorVM.newQueryTab(connectionId: config.id)
                    }) {
                        Image(systemName: "play")
                            .font(.system(size: 10))
                            .foregroundColor(.accentGreen)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 18, height: 18)
                    .opacity(hoveredId == config.id ? 1 : 0)
                } else if case .error(let msg) = state {
                    Text("!")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.accentRed)
                        .help(msg)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 4)
            .padding(.vertical, 3)
            .frame(height: 26)
            .background(hoveredId == config.id ? Color.bgHover : Color.clear)
            .onHover { hovering in
                hoveredId = hovering ? config.id : nil
            }
            .onTapGesture {
                toggleConnection(config)
            }
            .contextMenu {
                if state.isConnected {
                    Button("Disconnect") {
                        Task { await databaseService.disconnect(configID: config.id) }
                    }
                }
                Button("Edit Connection") {
                    connectionToEdit = config
                }
                Button("Remove Connection") {
                    databaseService.removeConnection(config)
                }
            }

            if expandedItems.contains(connId), let children = cachedChildren[connId] {
                ForEach(children) { entry in
                    treeRow(entry, depth: 1, configID: config.id)
                }
            }
        }
    }

    private func environmentBadge(_ env: String) -> some View {
        let color: Color = {
            switch env.lowercased() {
            case "dev", "development": return .accentGreen
            case "staging", "stage", "qa": return .accentYellow
            case "prod", "production": return .accentRed
            default: return .accentBlue
            }
        }()
        return Text(env.prefix(3).uppercased())
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.15))
            .cornerRadius(3)
    }

    // MARK: - Tree Row

    private func treeRow(_ entry: DBTreeEntry, depth: Int, configID: String, databaseName: String? = nil) -> some View {
        let isExpanded = expandedItems.contains(entry.id)
        let isLoading = loadingItems.contains(entry.id)
        let isSearching = !searchText.isEmpty
        let matchesSearch: Bool = {
            guard isSearching else { return true }
            let q = searchText.lowercased()
            return entry.name.lowercased().contains(q)
        }()

        if isSearching && !matchesSearch && !isExpanded {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    if entry.isExpandable {
                        Button(action: { handleExpand(entry, configID: configID) }) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(.textTertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 16, height: 16)
                    } else {
                        Spacer().frame(width: 16)
                    }

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: iconFor(entry))
                            .font(.system(size: 12))
                            .foregroundColor(colorFor(entry))
                    }

                    let isSection: Bool = {
                        if case .schemaSection = entry { return true }
                        return false
                    }()

                    Text(entry.name)
                        .font(.system(size: 13, weight: isSection ? .medium : .regular))
                        .foregroundColor(isSection ? .textPrimary : .textSecondary)
                        .lineLimit(1)

                    if case .table(let t) = entry {
                        let rowCountKey = "\(configID):\(t.schema):\(t.name)"
                        if let count = rowCounts[rowCountKey] {
                            Text("(\(count))")
                                .font(.system(size: 10))
                                .foregroundColor(.textTertiary)
                                .lineLimit(1)
                        } else if loadingRowCounts.contains(rowCountKey) {
                            ProgressView()
                                .scaleEffect(0.4)
                                .frame(width: 10, height: 10)
                        }
                    }

                    if case .column(let col, _) = entry {
                        Text(col.dataType)
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)
                            .lineLimit(1)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.borderDefault.opacity(0.3))
                            .cornerRadius(3)
                    }

                    Spacer()

                    if case .database = entry, isExpanded {
                        Circle()
                            .fill(Color.accentGreen)
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.leading, CGFloat(8 + depth * 16))
                .padding(.trailing, 4)
                .padding(.vertical, 2)
                .frame(height: 24)
                .background(hoveredId == entry.id ? Color.bgHover : Color.clear)
                .onHover { hovering in
                    hoveredId = hovering ? entry.id : nil
                }
                .contextMenu {
                    switch entry {
                    case .table(let t):
                        Button("Select Top 100") {
                            selectTop100(schema: t.schema, table: t.name, configID: configID)
                        }
                        Divider()
                        Button("View DDL") {
                            viewDDL(configID: configID, table: TableID(schema: t.schema, table: t.name), name: t.name)
                        }
                        Divider()
                        Button("ER Diagram") {
                            let dbName = databaseName ?? databaseService.config(withID: configID)?.name ?? configID
                            editorVM.openDiagramTab(configID: configID, schema: t.schema, databaseName: dbName)
                        }
                        Divider()
                        Button("Add Column") {
                            alterColumnConfigID = configID
                            alterColumnTable = TableID(schema: t.schema, table: t.name)
                            alterColumnInfo = nil
                            alterColumnMode = .add
                            showAlterColumn = true
                        }
                        Button("Manage Indexes") {
                            indexManagementConfigID = configID
                            indexManagementTable = TableID(schema: t.schema, table: t.name)
                            showIndexManagement = true
                        }
                        Divider()
                        Button("Copy Name") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("\(t.schema).\(t.name)", forType: .string)
                        }
                        Divider()
                        Button("Drop Table...", role: .destructive) {
                            dropConfigID = configID
                            dropTarget = "\(t.schema).\(t.name)"
                            dropType = "Table"
                            dropTableID = TableID(schema: t.schema, table: t.name)
                            dropCascade = false
                            dropErrorMessage = nil
                            showDropAlert = true
                        }
                    case .function(let f):
                        Button("Copy Name") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(f.name, forType: .string)
                        }
                        Divider()
                        Button("Drop Function...", role: .destructive) {
                            dropConfigID = configID
                            dropTarget = f.name
                            dropType = "Function"
                            dropTableID = TableID(schema: f.schema, table: f.name)
                            dropCascade = false
                            dropErrorMessage = nil
                            showDropAlert = true
                        }
                    case .procedure(let p):
                        Button("Copy Name") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(p.name, forType: .string)
                        }
                        Divider()
                        Button("Drop Procedure...", role: .destructive) {
                            dropConfigID = configID
                            dropTarget = p.name
                            dropType = "Procedure"
                            dropTableID = TableID(schema: p.schema, table: p.name)
                            dropCascade = false
                            dropErrorMessage = nil
                            showDropAlert = true
                        }
                    case .schemaSection(let sec):
                        if sec.sectionType == .tables {
                            Button("New Table") {
                                createTableConfigID = configID
                                createTableSchema = sec.schema
                                showCreateTable = true
                            }
                            Divider()
                            Button("ER Diagram") {
                                let dbName = databaseName ?? databaseService.config(withID: configID)?.name ?? configID
                                editorVM.openDiagramTab(configID: configID, schema: sec.schema, databaseName: dbName)
                            }
                        }
                    case .column(let col, let tableName):
                        if let schema = findSchema(for: entry, configID: configID) {
                            Button("Alter Column...") {
                                alterColumnConfigID = configID
                                alterColumnTable = TableID(schema: schema, table: tableName)
                                alterColumnInfo = col
                                alterColumnMode = .alter
                                showAlterColumn = true
                            }
                            Divider()
                            Button("Drop Column...", role: .destructive) {
                                dropConfigID = configID
                                dropTarget = col.name
                                dropType = "Column"
                                dropTableID = TableID(schema: schema, table: tableName)
                                dropCascade = false
                                dropErrorMessage = nil
                                showDropAlert = true
                            }
                        }
                    default:
                        EmptyView()
                    }
                }
                .onTapGesture(count: 2) {
                    if case .table(let t) = entry {
                        selectTop100(schema: t.schema, table: t.name, configID: configID)
                    }
                }
                .onTapGesture {
                    if entry.isExpandable {
                        handleExpand(entry, configID: configID)
                    }
                }

                if isExpanded, let children = cachedChildren[entry.id] {
                    let childDbName: String? = {
                        if case .database(let name) = entry { name }
                        else { databaseName }
                    }()
                    ForEach(children) { child in
                        treeRow(child, depth: depth + 1, configID: configID, databaseName: childDbName)
                    }
                }
            }
        )
    }

    // MARK: - Saved Queries Section

    private var savedQueriesSection: some View {
        SavedQueriesView()
            .environmentObject(databaseService)
            .environmentObject(editorVM)
            .padding(.top, 8)
    }

    // MARK: - Actions

    private func toggleConnection(_ config: ConnectionConfig) {
        let connId = "conn:\(config.id)"
        let state = databaseService.state(for: config.id)

        if expandedItems.contains(connId) {
            expandedItems.remove(connId)
            return
        }

        if !state.isConnected {
            if case .connecting = state {
                expandedItems.insert(connId)
                loadingItems.insert(connId)
                Task { await waitForConnectionThenLoadDatabases(config, connId: connId) }
                return
            }
            if let password = databaseService.password(for: config.id) {
                expandedItems.insert(connId)
                loadingItems.insert(connId)
                Task {
                    await databaseService.connect(config, password: password)
                    if databaseService.state(for: config.id).isConnected {
                        await loadDatabases(config, connId: connId)
                    } else {
                        expandedItems.remove(connId)
                        loadingItems.remove(connId)
                    }
                }
            } else {
                showConnectionSheet = true
            }
            return
        }

        expandedItems.insert(connId)
        loadingItems.insert(connId)

        Task {
            await loadDatabases(config, connId: connId)
        }
    }

    private func waitForConnectionThenLoadDatabases(_ config: ConnectionConfig, connId: String) async {
        for _ in 0..<40 {
            try? await Task.sleep(nanoseconds: 250_000_000)
            let s = databaseService.state(for: config.id)
            if case .connected = s {
                await loadDatabases(config, connId: connId)
                return
            }
            if case .error = s {
                expandedItems.remove(connId)
                loadingItems.remove(connId)
                return
            }
        }
        expandedItems.remove(connId)
        loadingItems.remove(connId)
    }

    private func loadDatabases(_ config: ConnectionConfig, connId: String) async {
        let databases = await databaseService.fetchDatabases(configID: config.id)
        let entries = databases.map { DBTreeEntry.database($0.name) }
        cachedChildren[connId] = entries
        loadingItems.remove(connId)
    }

    private func handleExpand(_ entry: DBTreeEntry, configID: String) {
        if expandedItems.contains(entry.id) {
            expandedItems.remove(entry.id)
            return
        }

        expandedItems.insert(entry.id)
        loadingItems.insert(entry.id)
        cachedChildren[entry.id] = []

        if case .database(let name) = entry {
            Task {
                let config = databaseService.config(withID: configID)
                if let config = config {
                    let needsReconnect = config.database != name
                    if needsReconnect {
                        let password = databaseService.password(for: configID) ?? ""
                        await databaseService.disconnect(configID: configID)
                        await databaseService.connect(config, password: password, database: name)
                    }
                }
                if databaseService.state(for: configID).isConnected {
                    let children = await loadChildren(for: entry, configID: configID)
                    cachedChildren[entry.id] = children
                }
                loadingItems.remove(entry.id)
            }
        } else {
            Task {
                let children = await loadChildren(for: entry, configID: configID)
                cachedChildren[entry.id] = children

                if case .table(let t) = entry {
                    loadRowCount(configID: configID, schema: t.schema, table: t.name)
                }

                loadingItems.remove(entry.id)
            }
        }
    }

    private func loadChildren(for entry: DBTreeEntry, configID: String) async -> [DBTreeEntry] {
        let result: [DBTreeEntry]

        switch entry {
        case .connection:
            let databases = await databaseService.fetchDatabases(configID: configID)
            result = databases.map { DBTreeEntry.database($0.name) }

        case .database:
            let schemas = await databaseService.fetchSchemas(configID: configID)
            result = schemas.map { DBTreeEntry.schema($0) }

        case .schema(let s):
            result = [
                DBTreeEntry.schemaSection(SchemaSection(sectionType: .tables, schema: s.name)),
                DBTreeEntry.schemaSection(SchemaSection(sectionType: .views, schema: s.name)),
                DBTreeEntry.schemaSection(SchemaSection(sectionType: .materializedViews, schema: s.name)),
                DBTreeEntry.schemaSection(SchemaSection(sectionType: .functions, schema: s.name)),
                DBTreeEntry.schemaSection(SchemaSection(sectionType: .procedures, schema: s.name)),
            ]

        case .schemaSection(let sec):
            switch sec.sectionType {
            case .tables:
                let tables = await databaseService.fetchTables(configID: configID, schema: sec.schema)
                result = tables.filter { $0.tableType == .table }.map { DBTreeEntry.table($0) }
            case .views:
                let tables = await databaseService.fetchTables(configID: configID, schema: sec.schema)
                result = tables.filter { $0.tableType == .view }.map { DBTreeEntry.table($0) }
            case .materializedViews:
                let tables = await databaseService.fetchTables(configID: configID, schema: sec.schema)
                result = tables.filter { $0.tableType == .materializedView }.map { DBTreeEntry.table($0) }
            case .functions:
                let funcs = await databaseService.fetchFunctions(configID: configID, schema: sec.schema)
                result = funcs.map { DBTreeEntry.function($0) }
            case .procedures:
                let procs = await databaseService.fetchProcedures(configID: configID, schema: sec.schema)
                result = procs.map { DBTreeEntry.procedure($0) }
            }

        case .table(let t):
            let columns = await databaseService.fetchColumns(
                configID: configID,
                table: TableID(schema: t.schema, table: t.name)
            )
            result = columns.map { DBTreeEntry.column($0, tableName: t.name) }

        default:
            result = []
        }

        return result
    }

    private func loadRowCount(configID: String, schema: String, table: String) {
        let key = "\(configID):\(schema):\(table)"
        guard !loadingRowCounts.contains(key) else { return }
        loadingRowCounts.insert(key)
        Task {
            let count = await databaseService.fetchRowCount(configID: configID, schema: schema, table: table)
            rowCounts[key] = count
            loadingRowCounts.remove(key)
        }
    }

    private func selectTop100(schema: String, table: String, configID: String) {
        let sql = "SELECT * FROM \"\(schema)\".\"\(table)\""
        let tab = Tab(
            name: table,
            type: .queryResult,
            queryConnectionId: configID,
            querySql: sql,
            queryTableSchema: schema,
            queryTableName: table
        )
        editorVM.tabs.append(tab)
        editorVM.querySql[tab.id] = sql
        editorVM.activeTabId = tab.id
        editorVM.saveTabsToWorktree()

        Task { @MainActor in
            let result = await databaseService.execute(configID: configID, sql: sql)
            editorVM.queryResults[tab.id] = result
        }
    }

    private func viewDDL(configID: String, table: TableID, name: String) {
        Task { @MainActor in
            let ddl = await databaseService.fetchTableDDL(configID: configID, table: table)
            let tab = Tab(
                name: "DDL: \(name)",
                type: .queryResult,
                queryConnectionId: configID,
                querySql: ddl
            )
            editorVM.tabs.append(tab)
            editorVM.querySql[tab.id] = ddl
            editorVM.activeTabId = tab.id
            editorVM.saveTabsToWorktree()

            let result = QueryPageResult(
                columns: [name],
                columnTypes: ["text"],
                rows: ddl.split(separator: "\n").map { [String($0)] },
                totalCount: 1,
                page: 0,
                pageSize: 1,
                executionTime: 0
            )
            editorVM.queryResults[tab.id] = result
        }
    }

    private func performDrop() {
        let configID = dropConfigID
        let tableID = dropTableID
        let isCascade = dropCascade

        Task { @MainActor in
            do {
                switch dropType {
                case "Table":
                    try await databaseService.dropTable(configID: configID, table: tableID, cascade: isCascade)
                case "Column":
                    let sql = "ALTER TABLE \"\(tableID.schema)\".\"\(tableID.table)\" DROP COLUMN \"\(dropTarget)\""
                    let result = await databaseService.execute(configID: configID, sql: sql)
                    if let error = result.error {
                        dropErrorMessage = error
                        return
                    }
                default:
                    let sql: String
                    if dropType == "Function" {
                        sql = "DROP FUNCTION \"\(dropTarget)\" CASCADE"
                    } else if dropType == "Procedure" {
                        sql = "DROP PROCEDURE \"\(dropTarget)\" CASCADE"
                    } else {
                        sql = "ALTER TABLE \"\(tableID.schema)\".\"\(tableID.table)\" DROP COLUMN \"\(dropTarget)\""
                    }
                    let result = await databaseService.execute(configID: configID, sql: sql)
                    if let error = result.error {
                        dropErrorMessage = error
                        return
                    }
                }
                dropCascade = false
                dropErrorMessage = nil
                showDropAlert = false
                refreshAllCaches()
            } catch {
                dropErrorMessage = error.localizedDescription
            }
        }
    }

    private func refreshAllCaches() {
        let previouslyExpanded = expandedItems
        cachedChildren.removeAll()
        Task { @MainActor in
            for config in databaseService.connections {
                let connId = "conn:\(config.id)"
                guard previouslyExpanded.contains(connId) else { continue }
                await refreshChildrenRecursively(for: .connection(config, state: .disconnected), configID: config.id, expanded: previouslyExpanded)
            }
        }
    }

    private func refreshChildrenRecursively(for entry: DBTreeEntry, configID: String, expanded: Set<String>) async {
        guard entry.isExpandable, expanded.contains(entry.id) else { return }
        loadingItems.insert(entry.id)
        let children = await loadChildren(for: entry, configID: configID)
        cachedChildren[entry.id] = children
        loadingItems.remove(entry.id)
        for child in children {
            await refreshChildrenRecursively(for: child, configID: configID, expanded: expanded)
        }
    }

    private func findSchema(for entry: DBTreeEntry, configID: String) -> String? {
        if case .column(_, let tableName) = entry {
            for config in databaseService.connections {
                let connId = "conn:\(config.id)"
                if let connChildren = cachedChildren[connId] {
                    for dbEntry in connChildren {
                        if case .database = dbEntry {
                            if let schemaChildren = cachedChildren[dbEntry.id] {
                                for schemaEntry in schemaChildren {
                                    if case .schema(let s) = schemaEntry {
                                        let tablesSectionId = "\(s.name).Tables"
                                        if let tableChildren = cachedChildren[tablesSectionId] {
                                            for tableEntry in tableChildren {
                                                if case .table(let t) = tableEntry, t.name == tableName {
                                                    return s.name
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Helpers

    private func iconFor(_ entry: DBTreeEntry) -> String {
        switch entry {
        case .connection: return "server.rack"
        case .database: return "cylinder"
        case .schema: return "folder"
        case .schemaSection(let sec):
            switch sec.sectionType {
            case .tables: return "tablecells"
            case .views: return "list.clipboard"
            case .materializedViews: return "rectangle.stack"
            case .functions: return "f.cursive"
            case .procedures: return "gearshape.2"
            }
        case .table: return "tablecells"
        case .column(let col, _): return typeSFSymbol(for: col.dataType)
        case .function: return "f.cursive"
        case .procedure: return "gearshape.2"
        }
    }

    private func typeSFSymbol(for type: String) -> String {
        let lower = type.lowercased()
        if lower.contains("int") || lower.contains("serial") || lower.contains("numeric") || lower.contains("decimal") || lower.contains("float") || lower.contains("double") || lower.contains("real") || lower.contains("money") {
            return "number"
        }
        if lower.contains("char") || lower.contains("text") || lower.contains("varchar") || lower.contains("name") || lower.contains("json") || lower.contains("xml") || lower.contains("uuid") {
            return "textformat"
        }
        if lower.contains("bool") {
            return "switch.2"
        }
        if lower.contains("date") || lower.contains("time") || lower.contains("timestamp") || lower.contains("interval") {
            return "calendar"
        }
        if lower.contains("bytea") || lower.contains("blob") || lower.contains("binary") {
            return "doc"
        }
        if lower.contains("inet") || lower.contains("cidr") || lower.contains("macaddr") {
            return "network"
        }
        if lower.contains("point") || lower.contains("line") || lower.contains("polygon") || lower.contains("circle") || lower.contains("geometry") || lower.contains("geography") || lower.contains("path") || lower.contains("box") {
            return "triangle"
        }
        if lower.contains("array") || lower.contains("[]") {
            return "list.bullet"
        }
        return "questionmark.diamond"
    }

    private func colorFor(_ entry: DBTreeEntry) -> Color {
        switch entry {
        case .connection: return .accentBlue
        case .database: return .accentYellow
        case .schema: return .folderYellow
        case .schemaSection(let sec):
            switch sec.sectionType {
            case .tables: return .accentBlue
            case .views: return .accentGreen
            case .materializedViews: return .accentBlue
            case .functions: return .accentPurple
            case .procedures: return .accentOrange
            }
        case .table: return .accentBlue
        case .column: return .textTertiary
        case .function: return .accentPurple
        case .procedure: return .accentOrange
        }
    }

    private func connectionDotColor(for state: SessionState) -> Color {
        switch state {
        case .disconnected: return .textTertiary
        case .connecting: return .accentYellow
        case .connected: return .accentGreen
        case .error: return .accentRed
        }
    }
}
