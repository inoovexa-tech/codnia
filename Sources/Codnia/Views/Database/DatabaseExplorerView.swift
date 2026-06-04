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
    @State private var showTableProperties = false
    @State private var tablePropertiesConfigID = ""
    @State private var tablePropertiesTable = TableID(schema: "", table: "")
    @State private var showRoutineEditor = false
    @State private var routineEditorConfigID = ""
    @State private var routineEditorSchema = ""
    @State private var routineEditorName = ""
    @State private var routineEditorType: RoutineType = .view
    @State private var showConstraintManagement = false
    @State private var constraintManagementConfigID = ""
    @State private var constraintManagementTable = TableID(schema: "", table: "")
    @State private var constraintManagementSchema = ""
    @State private var showDependencies = false
    @State private var dependenciesConfigID = ""
    @State private var dependenciesTable = TableID(schema: "", table: "")
    @State private var showTableEditor = false
    @State private var tableEditorConfigID = ""
    @State private var tableEditorTable = TableID(schema: "", table: "")
    @State private var showDropAlert = false
    @State private var dropConfigID = ""
    @State private var dropTarget = ""
    @State private var dropType = ""
    @State private var dropTableID = TableID(schema: "", table: "")
    @State private var dropCascade = false
    @State private var dropErrorMessage: String?
    @State private var searchText = ""
    @State private var rowCounts: [String: Int] = [:]
    @State private var tableGroups: [String: [TableGroup]] = [:]
    @State private var showCreateGroup = false
    @State private var createGroupSchema = ""
    @State private var createGroupConfigID = ""
    @State private var renameGroupId: String?
    @State private var renameGroupSchema = ""
    @State private var renameGroupName = ""
    @State private var renameGroupConfigID = ""

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
        .sheet(isPresented: $showTableProperties) {
            TablePropertiesView(configID: tablePropertiesConfigID, table: tablePropertiesTable)
                .environmentObject(databaseService)
        }
        .sheet(isPresented: $showRoutineEditor) {
            RoutineEditorView(
                configID: routineEditorConfigID,
                schema: routineEditorSchema,
                name: routineEditorName,
                type: routineEditorType
            )
            .environmentObject(databaseService)
        }
        .sheet(isPresented: $showConstraintManagement) {
            ConstraintManagementView(
                configID: constraintManagementConfigID,
                table: constraintManagementTable,
                schema: constraintManagementSchema
            )
            .environmentObject(databaseService)
        }
        .sheet(isPresented: $showDependencies) {
            DependenciesView(
                configID: dependenciesConfigID,
                table: dependenciesTable
            )
            .environmentObject(databaseService)
        }
        .sheet(isPresented: $showTableEditor) {
            TableEditorView(
                configID: tableEditorConfigID,
                table: tableEditorTable
            )
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
        .alert("New Group", isPresented: $showCreateGroup, actions: {
            TextField("Group name", text: $renameGroupName)
            Button("Cancel", role: .cancel) {
                renameGroupName = ""
            }
            Button("Create") {
                let name = renameGroupName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    createGroup(name: name, schema: createGroupSchema)
                    cachedChildren.removeValue(forKey: "section:tables:\(createGroupConfigID):\(createGroupSchema)")
                }
                renameGroupName = ""
            }
        }, message: {
            Text("Enter a name for the new table group")
        })
        .alert("Rename Group", isPresented: .init(get: { renameGroupId != nil }, set: { if !$0 { renameGroupId = nil } }), actions: {
            TextField("Group name", text: $renameGroupName)
            Button("Cancel", role: .cancel) {
                renameGroupId = nil
                renameGroupSchema = ""
                renameGroupName = ""
            }
            Button("Rename") {
                let name = renameGroupName.trimmingCharacters(in: .whitespaces)
                if let id = renameGroupId, !name.isEmpty {
                    renameGroup(id: id, name: name, schema: renameGroupSchema)
                    cachedChildren.removeValue(forKey: "section:tables:\(renameGroupConfigID):\(renameGroupSchema)")
                }
                renameGroupId = nil
                renameGroupSchema = ""
                renameGroupName = ""
                renameGroupConfigID = ""
            }
        })
        .onChange(of: databaseService.schemaVersion) { _ in
            refreshAllCaches()
        }
        .onAppear {
            loadSession()
            loadGroups()
        }
        .onDisappear {
            saveSession()
            saveGroups()
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

                config.type.logoView(size: 14)

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
                } else {
                    Button("Connect") {
                        connectConfig(config)
                    }
                }
                Divider()
                Button("Edit Connection...") {
                    connectionToEdit = config
                }
                Button("Remove Connection") {
                    databaseService.removeConnection(config)
                }
            }

            if expandedItems.contains(connId) {
                if let children = cachedChildren[connId] {
                    ForEach(children) { entry in
                        treeRow(entry, depth: 1, configID: config.id)
                    }
                }
                if let errorMsg = databaseService.fetchErrors[config.id] {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.accentRed)
                        Text(errorMsg)
                            .font(.system(size: 11))
                            .foregroundColor(.accentRed)
                            .lineLimit(3)
                    }
                    .padding(.leading, 28)
                    .padding(.vertical, 4)
                    .padding(.trailing, 8)
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
                        Button("Edit Table") {
                            tableEditorConfigID = configID
                            tableEditorTable = TableID(schema: t.schema, table: t.name)
                            showTableEditor = true
                        }
                        if t.tableType == .view || t.tableType == .materializedView {
                            Button("Edit \(t.tableType == .view ? "View" : "Materialized View")") {
                                routineEditorConfigID = configID
                                routineEditorSchema = t.schema
                                routineEditorName = t.name
                                routineEditorType = .view
                                showRoutineEditor = true
                            }
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
                        Button("Manage Constraints") {
                            constraintManagementConfigID = configID
                            constraintManagementTable = TableID(schema: t.schema, table: t.name)
                            constraintManagementSchema = t.schema
                            showConstraintManagement = true
                        }
                        Button("Dependencies") {
                            dependenciesConfigID = configID
                            dependenciesTable = TableID(schema: t.schema, table: t.name)
                            showDependencies = true
                        }
                        Button("Properties") {
                            tablePropertiesConfigID = configID
                            tablePropertiesTable = TableID(schema: t.schema, table: t.name)
                            showTableProperties = true
                        }
                        Divider()
                        Divider()
                        Menu("Add to Group") {
                            let groups = tableGroups[t.schema] ?? []
                            if groups.isEmpty {
                                Text("No groups")
                            }
                            ForEach(groups, id: \.id) { g in
                                Button(g.name) {
                                    addTableToGroup(tableId: t.id, groupId: g.id, schema: t.schema, configID: configID)
                                }
                            }
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
                        Button("Edit Function") {
                            routineEditorConfigID = configID
                            routineEditorSchema = f.schema
                            routineEditorName = f.name
                            routineEditorType = .function
                            showRoutineEditor = true
                        }
                        Divider()
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
                        Button("Edit Procedure") {
                            routineEditorConfigID = configID
                            routineEditorSchema = p.schema
                            routineEditorName = p.name
                            routineEditorType = .procedure
                            showRoutineEditor = true
                        }
                        Divider()
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
                            Button("New Group") {
                                createGroupConfigID = configID
                                createGroupSchema = sec.schema
                                showCreateGroup = true
                            }
                            Divider()
                            Button("Export Schema DDL…") {
                                exportSchemaDDL(configID: configID, schema: sec.schema)
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
                    case .tableGroup(let g, let schema):
                        Button("Rename Group") {
                            renameGroupId = g.id
                            renameGroupSchema = schema
                            renameGroupName = g.name
                            renameGroupConfigID = configID
                        }
                        Button("Remove Group", role: .destructive) {
                            removeGroup(g.id, schema: schema)
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

    private func connectConfig(_ config: ConnectionConfig) {
        let state = databaseService.state(for: config.id)
        guard !state.isConnected, case .disconnected = state else { return }

        if let password = databaseService.password(for: config.id) {
            Task {
                await databaseService.connect(config, password: password)
            }
        } else {
            connectionToEdit = config
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
                    let currentDb = databaseService.activeDatabases[configID]
                    let needsReconnect = currentDb != name
                    if needsReconnect {
                        // Clear caches from the previous database before disconnecting
                        await clearSubtreeCaches(for: configID, except: name)
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
                DBTreeEntry.schemaSection(SchemaSection(sectionType: .triggers, schema: s.name)),
                DBTreeEntry.schemaSection(SchemaSection(sectionType: .sequences, schema: s.name)),
            ]

        case .schemaSection(let sec):
            switch sec.sectionType {
            case .tables:
                let allTables = await databaseService.fetchTables(configID: configID, schema: sec.schema)
                let tables = allTables.filter { $0.tableType == .table }
                let groups = self.tableGroups[sec.schema] ?? []
                let groupedIds = Set(groups.flatMap { $0.tableIds })
                var entries: [DBTreeEntry] = []
                for g in groups {
                    entries.append(.tableGroup(g, schema: sec.schema))
                }
                let ungrouped = tables.filter { !groupedIds.contains($0.id) }
                entries.append(contentsOf: ungrouped.map { DBTreeEntry.table($0) })
                result = entries
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
            case .triggers:
                let trigs = await databaseService.fetchTriggers(configID: configID, schema: sec.schema)
                result = trigs.map { DBTreeEntry.trigger($0) }
            case .sequences:
                let seqs = await databaseService.fetchSequences(configID: configID, schema: sec.schema)
                result = seqs.map { DBTreeEntry.sequence($0) }
            }

        case .table(let t):
            let columns = await databaseService.fetchColumns(
                configID: configID,
                table: TableID(schema: t.schema, table: t.name)
            )
            result = columns.map { DBTreeEntry.column($0, tableName: t.name) }

        case .tableGroup(let g, let schema):
            let allTables = await databaseService.fetchTables(configID: configID, schema: schema)
            let groupTables = allTables.filter { g.tableIds.contains($0.id) }
            result = groupTables.map { DBTreeEntry.table($0) }

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
        guard let qSchema = databaseService.quoteIdentifier(configID: configID, schema),
              let qTable = databaseService.quoteIdentifier(configID: configID, table)
        else { return }
        let sql = "SELECT * FROM \(qSchema).\(qTable)"
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

    private var sessionStorageURL: URL? {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Codnia")
            .appendingPathComponent("Sessions")
        try? FileManager.default.createDirectory(at: dir!, withIntermediateDirectories: true)
        return dir?.appendingPathComponent("explorer_state.json")
    }

    private func saveSession() {
        guard let url = sessionStorageURL else { return }
        let dict: [String: Any] = [
            "expandedItems": Array(expandedItems)
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        try? data.write(to: url)
    }

    private func loadSession() {
        guard let url = sessionStorageURL,
              let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = dict["expandedItems"] as? [String]
        else { return }
        expandedItems = Set(items)
    }

    private var groupsStorageURL: URL? {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Codnia")
            .appendingPathComponent("Sessions")
        try? FileManager.default.createDirectory(at: dir!, withIntermediateDirectories: true)
        return dir?.appendingPathComponent("table_groups.json")
    }

    private func saveGroups() {
        guard let url = groupsStorageURL,
              let data = try? JSONEncoder().encode(tableGroups)
        else { return }
        try? data.write(to: url)
    }

    private func loadGroups() {
        guard let url = groupsStorageURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [TableGroup]].self, from: data)
        else { return }
        tableGroups = decoded
    }

    private func createGroup(name: String, schema: String) {
        let g = TableGroup(name: name)
        var groups = tableGroups[schema] ?? []
        groups.append(g)
        tableGroups[schema] = groups
        saveGroups()
    }

    private func removeGroup(_ id: String, schema: String) {
        var groups = tableGroups[schema] ?? []
        groups.removeAll { $0.id == id }
        tableGroups[schema] = groups.isEmpty ? nil : groups
        saveGroups()
    }

    private func renameGroup(id: String, name: String, schema: String) {
        guard var groups = tableGroups[schema],
              let idx = groups.firstIndex(where: { $0.id == id })
        else { return }
        groups[idx].name = name
        tableGroups[schema] = groups
        saveGroups()
    }

    private func addTableToGroup(tableId: String, groupId: String, schema: String, configID: String) {
        guard var groups = tableGroups[schema],
              let idx = groups.firstIndex(where: { $0.id == groupId })
        else { return }
        if !groups[idx].tableIds.contains(tableId) {
            groups[idx].tableIds.append(tableId)
        }
        tableGroups[schema] = groups
        saveGroups()
        cachedChildren.removeValue(forKey: "section:tables:\(configID):\(schema)")
    }

    private func exportSchemaDDL(configID: String, schema: String) {
        Task {
            let ddl = await databaseService.exportSchemaDDL(configID: configID, schema: schema)
            guard !ddl.isEmpty else { return }
            let panel = NSSavePanel()
            panel.title = "Export Schema DDL"
            panel.nameFieldStringValue = "\(schema).sql"
            panel.allowedContentTypes = [.plainText]
            panel.canCreateDirectories = true
            NSApp.activate(ignoringOtherApps: true)
            let response = panel.runModal()
            guard response == .OK, let url = panel.url else { return }
            try? ddl.write(to: url, atomically: true, encoding: .utf8)
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
                    guard let qSchema = databaseService.quoteIdentifier(configID: configID, tableID.schema),
                          let qTable = databaseService.quoteIdentifier(configID: configID, tableID.table),
                          let qCol = databaseService.quoteIdentifier(configID: configID, dropTarget)
                    else { return }
                    let sql = "ALTER TABLE \(qSchema).\(qTable) DROP COLUMN \(qCol)"
                    let result = await databaseService.execute(configID: configID, sql: sql)
                    if let error = result.error {
                        dropErrorMessage = error
                        return
                    }
                default:
                    let sql: String
                    if dropType == "Function" {
                        guard let qFunc = databaseService.quoteIdentifier(configID: configID, dropTarget) else { return }
                        sql = "DROP FUNCTION \(qFunc) CASCADE"
                    } else if dropType == "Procedure" {
                        guard let qProc = databaseService.quoteIdentifier(configID: configID, dropTarget) else { return }
                        sql = "DROP PROCEDURE \(qProc) CASCADE"
                    } else {
                        guard let qSchema = databaseService.quoteIdentifier(configID: configID, tableID.schema),
                              let qTable = databaseService.quoteIdentifier(configID: configID, tableID.table),
                              let qCol = databaseService.quoteIdentifier(configID: configID, dropTarget)
                        else { return }
                        sql = "ALTER TABLE \(qSchema).\(qTable) DROP COLUMN \(qCol)"
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

    private func clearSubtreeCaches(for configID: String, except databaseName: String) async {
        let connId = "conn:\(configID)"
        if let dbEntries = cachedChildren[connId] {
            for dbEntry in dbEntries {
                if case .database(let name) = dbEntry, name != databaseName {
                    clearDescendantCaches(of: dbEntry.id)
                }
            }
        }
    }

    private func clearDescendantCaches(of entryId: String) {
        guard let children = cachedChildren[entryId] else { return }
        cachedChildren.removeValue(forKey: entryId)
        expandedItems.remove(entryId)
        for child in children {
            clearDescendantCaches(of: child.id)
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
            case .triggers: return "bolt"
            case .sequences: return "list.number"
            }
        case .table: return "tablecells"
        case .column(let col, _): return typeSFSymbol(for: col.dataType)
        case .function: return "f.cursive"
        case .procedure: return "gearshape.2"
        case .trigger: return "bolt"
        case .sequence: return "list.number"
        case .constraint: return "lock"
        case .tableGroup: return "folder"
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
            case .triggers: return .accentYellow
            case .sequences: return .accentGreen
            }
        case .table: return .accentBlue
        case .column: return .textTertiary
        case .function: return .accentPurple
        case .procedure: return .accentOrange
        case .trigger: return .accentYellow
        case .sequence: return .accentGreen
        case .constraint: return .accentBlue
        case .tableGroup: return .accentOrange
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
