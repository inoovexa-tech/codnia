import SwiftUI

struct ConstraintManagementView: View {
    let configID: String
    let table: TableID
    let schema: String

    @EnvironmentObject var databaseService: DatabaseConnectionService
    @Environment(\.dismiss) private var dismiss

    @State private var constraints: [ConstraintInfo] = []
    @State private var isLoading = true
    @State private var showNewFK = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 500, height: 450)
        .task { await loadConstraints() }
        .sheet(isPresented: $showNewFK) { newFKSheet }
    }

    private var header: some View {
        HStack {
            Image(systemName: "lock")
                .font(.system(size: 12))
                .foregroundColor(.accentBlue)
            Text("Manage Constraints")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Text("\(table.schema).\(table.table)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.textTertiary)
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var content: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Loading constraints...")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                    Spacer()
                }
            } else if constraints.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "lock.open")
                        .font(.system(size: 28))
                        .foregroundColor(.textTertiary)
                    Text("No constraints")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                    Text("Add a foreign key constraint to link tables")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        let grouped = Dictionary(grouping: constraints, by: { $0.type })
                        ForEach(grouped.keys.sorted(by: typeOrder), id: \.self) { type in
                            if let group = grouped[type] {
                                constraintGroup(type, constraints: group)
                            }
                        }
                    }
                }
            }
        }
    }

    private func constraintGroup(_ type: ConstraintInfo.ConstraintType, constraints: [ConstraintInfo]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(type.rawValue)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(typeColor(type))
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            ForEach(constraints) { c in
                constraintRow(c)
            }
        }
    }

    private func constraintRow(_ c: ConstraintInfo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: typeIcon(c.type))
                .font(.system(size: 10))
                .foregroundColor(typeColor(c.type))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(c.name)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.textPrimary)
                if !c.columns.isEmpty {
                    Text("(\(c.columns.joined(separator: ", ")))")
                        .font(.system(size: 9))
                        .foregroundColor(.textTertiary)
                }
                if let def = c.definition {
                    Text(def)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.textTertiary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if c.type != .primaryKey {
                Button(action: {
                    Task { await dropConstraint(c) }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.accentRed)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Drop constraint")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func typeIcon(_ type: ConstraintInfo.ConstraintType) -> String {
        switch type {
        case .primaryKey: return "key.fill"
        case .foreignKey: return "link"
        case .unique: return "checkmark.circle"
        case .check: return "exclamationmark.triangle"
        case .exclude: return "nosign"
        }
    }

    private func typeColor(_ type: ConstraintInfo.ConstraintType) -> Color {
        switch type {
        case .primaryKey: return .accentYellow
        case .foreignKey: return .accentBlue
        case .unique: return .accentGreen
        case .check: return .accentOrange
        case .exclude: return .accentRed
        }
    }

    private var footer: some View {
        HStack {
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.accentRed)
            }
            Spacer()
            Button(action: { showNewFK = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                    Text("New Foreign Key")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.accentBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.accentBlue.opacity(0.1))
                .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())

            Button("Close", action: { dismiss() })
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - New FK Sheet

    private var newFKSheet: some View {
        NewForeignKeyView(
            configID: configID,
            table: table,
            schema: schema,
            onSave: { await loadConstraints() },
            onDismiss: { showNewFK = false }
        )
        .environmentObject(databaseService)
    }

    private func loadConstraints() async {
        isLoading = true
        constraints = await databaseService.fetchConstraints(configID: configID, table: table)
        isLoading = false
    }

    private func dropConstraint(_ c: ConstraintInfo) async {
        errorMessage = nil
        do {
            try await databaseService.dropConstraint(configID: configID, table: table, constraint: c.name)
            await loadConstraints()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func typeOrder(_ a: ConstraintInfo.ConstraintType, _ b: ConstraintInfo.ConstraintType) -> Bool {
        let order: [ConstraintInfo.ConstraintType: Int] = [
            .primaryKey: 0, .foreignKey: 1, .unique: 2, .check: 3, .exclude: 4
        ]
        return (order[a] ?? 5) < (order[b] ?? 5)
    }
}

// MARK: - New Foreign Key Sheet

struct NewForeignKeyView: View {
    let configID: String
    let table: TableID
    let schema: String
    let onSave: () async -> Void
    let onDismiss: () -> Void

    @EnvironmentObject var databaseService: DatabaseConnectionService

    @State private var tables: [TableInfo] = []
    @State private var selectedTable: String = ""
    @State private var sourceColumns: [String] = []
    @State private var refColumns: [String] = []
    @State private var selectedSourceCols: Set<String> = []
    @State private var selectedRefCols: Set<String> = []
    @State private var constraintName = ""
    @State private var onDelete: String = "NO ACTION"
    @State private var onUpdate: String = "NO ACTION"
    @State private var isLoading = true
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let fkActions = ["NO ACTION", "RESTRICT", "CASCADE", "SET NULL", "SET DEFAULT"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Foreign Key")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Constraint Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Constraint Name")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textTertiary)
                        TextField("fk_table_column", text: $constraintName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }

                    // Source Columns
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Source Columns (from \(table.table))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textTertiary)
                        if sourceColumns.isEmpty {
                            Text("Loading columns...")
                                .font(.system(size: 11))
                                .foregroundColor(.textTertiary)
                        } else {
                            ForEach(sourceColumns, id: \.self) { col in
                                Toggle(col, isOn: Binding(
                                    get: { selectedSourceCols.contains(col) },
                                    set: { isOn in
                                        if isOn { selectedSourceCols.insert(col) }
                                        else { selectedSourceCols.remove(col) }
                                    }
                                ))
                                .toggleStyle(.checkbox)
                                .font(.system(size: 12, design: .monospaced))
                            }
                        }
                    }

                    // Referenced Table
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Referenced Table")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textTertiary)
                        if tables.isEmpty {
                            Text("Loading tables...")
                                .font(.system(size: 11))
                                .foregroundColor(.textTertiary)
                        } else {
                            Picker("", selection: $selectedTable) {
                                Text("Select a table...").tag("")
                                ForEach(tables.map(\.name), id: \.self) { name in
                                    Text(name).tag(name)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .onChange(of: selectedTable) { _ in
                                selectedRefCols = []
                                loadRefColumns()
                            }
                        }
                    }

                    // Referenced Columns
                    if !selectedTable.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Referenced Columns")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textTertiary)
                            if refColumns.isEmpty {
                                Text("Loading columns...")
                                    .font(.system(size: 11))
                                    .foregroundColor(.textTertiary)
                            } else {
                                ForEach(refColumns, id: \.self) { col in
                                    Toggle(col, isOn: Binding(
                                        get: { selectedRefCols.contains(col) },
                                        set: { isOn in
                                            if isOn { selectedRefCols.insert(col) }
                                            else { selectedRefCols.remove(col) }
                                        }
                                    ))
                                    .toggleStyle(.checkbox)
                                    .font(.system(size: 12, design: .monospaced))
                                }
                            }
                        }
                    }

                    // On Delete / On Update
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("On Delete")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textTertiary)
                            Picker("", selection: $onDelete) {
                                ForEach(fkActions, id: \.self) { action in
                                    Text(action).tag(action)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("On Update")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textTertiary)
                            Picker("", selection: $onUpdate) {
                                ForEach(fkActions, id: \.self) { action in
                                    Text(action).tag(action)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }
                }
                .padding(16)
            }

            Divider()
            HStack {
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.accentRed)
                        .lineLimit(2)
                }
                Spacer()
                Button("Cancel", action: onDismiss)
                    .keyboardShortcut(.escape, modifiers: [])
                Button(action: createFK) {
                    HStack(spacing: 4) {
                        if isCreating { ProgressView().scaleEffect(0.5) }
                        Text("Create")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(canCreate ? Color.accentBlue : Color.gray)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canCreate || isCreating)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 400, height: 550)
        .task { await loadData() }
    }

    private var canCreate: Bool {
        !selectedSourceCols.isEmpty && !selectedTable.isEmpty && !selectedRefCols.isEmpty && selectedSourceCols.count == selectedRefCols.count
    }

    private func loadData() async {
        isLoading = true
        async let ts = databaseService.fetchTables(configID: configID, schema: schema)
        async let cols = databaseService.fetchColumns(configID: configID, table: table)
        let (tablesResult, colsResult) = await (ts, cols)
        tables = tablesResult
        sourceColumns = colsResult.map(\.name)
        isLoading = false
    }

    private func loadRefColumns() {
        guard !selectedTable.isEmpty else { return }
        Task {
            let refTable = TableID(schema: schema, table: selectedTable)
            let cols = await databaseService.fetchColumns(configID: configID, table: refTable)
            refColumns = cols.map(\.name)
        }
    }

    private func createFK() {
        let name = constraintName.trimmingCharacters(in: .whitespaces)
        let fkName = name.isEmpty ? "fk_\(table.table)_\(selectedTable)" : name
        isCreating = true
        errorMessage = nil
        Task {
            do {
                let refTable = TableID(schema: schema, table: selectedTable)
                try await databaseService.addForeignKey(
                    configID: configID,
                    table: table,
                    name: fkName,
                    columns: Array(selectedSourceCols).sorted(),
                    refTable: refTable,
                    refColumns: Array(selectedRefCols).sorted(),
                    onDelete: onDelete == "NO ACTION" ? nil : onDelete.replacingOccurrences(of: " ", with: "_"),
                    onUpdate: onUpdate == "NO ACTION" ? nil : onUpdate.replacingOccurrences(of: " ", with: "_")
                )
                await MainActor.run { isCreating = false }
                await onSave()
                onDismiss()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}
