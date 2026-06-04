import SwiftUI

struct TableEditorView: View {
    let configID: String
    let table: TableID

    @EnvironmentObject var databaseService: DatabaseConnectionService
    @Environment(\.dismiss) private var dismiss

    @State private var originalColumns: [ColumnInfo] = []
    @State private var editedColumns: [ColumnDef] = []
    @State private var isLoading = true
    @State private var isApplying = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let pgTypes = [
        "bigint", "bigserial", "bit", "boolean", "box", "bytea",
        "character", "character varying", "cidr", "circle", "date",
        "double precision", "inet", "integer", "interval", "json",
        "jsonb", "line", "lseg", "macaddr", "money", "numeric",
        "path", "pg_lsn", "point", "polygon", "real", "smallint",
        "smallserial", "serial", "text", "time", "timestamp",
        "timestamptz", "tsquery", "tsvector", "txid_snapshot", "uuid",
        "xml"
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if isLoading {
                loadingView
            } else {
                formContent
            }
            Divider()
            if successMessage == nil {
                previewSection
                Divider()
            }
            footer
        }
        .frame(width: 620, height: 560)
        .task {
            await loadColumns()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            Spacer()
            ProgressView()
            Text("Loading columns...")
                .font(.system(size: 12))
                .foregroundColor(.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Text("Edit Table: \(table.schema).\(table.table)")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if successMessage != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentGreen)
                    .font(.system(size: 14))
            }
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

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Columns")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Button(action: { editedColumns.append(ColumnDef()) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10))
                            Text("Add Column")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.accentBlue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                ForEach(editedColumns.indices, id: \.self) { idx in
                    columnRow(idx)
                }
            }
            .padding(16)
        }
    }

    private func columnRow(_ idx: Int) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("\(idx + 1)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .frame(width: 20)

                TextField("name", text: Binding(
                    get: { editedColumns[idx].name },
                    set: { editedColumns[idx].name = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 130)

                Picker("", selection: Binding(
                    get: { editedColumns[idx].type },
                    set: { editedColumns[idx].type = $0 }
                )) {
                    ForEach(pgTypes, id: \.self) { t in
                        Text(t).tag(t)
                    }
                }
                .labelsHidden()
                .frame(width: 150)

                if idx < originalColumns.count {
                    Text(originalColumns[idx].dataType)
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                }

                Button(action: { editedColumns.remove(at: idx) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.accentRed)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(editedColumns.count <= 1)
            }

            HStack(spacing: 12) {
                Toggle("Nullable", isOn: Binding(
                    get: { editedColumns[idx].isNullable },
                    set: { editedColumns[idx].isNullable = $0 }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)

                Toggle("PK", isOn: Binding(
                    get: { editedColumns[idx].isPrimaryKey },
                    set: { editedColumns[idx].isPrimaryKey = $0 }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)

                TextField("Default (optional)", text: Binding(
                    get: { editedColumns[idx].defaultValue },
                    set: { editedColumns[idx].defaultValue = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 180)
            }
        }
        .padding(8)
        .background(idx < originalColumns.count ? Color.bgHover.opacity(0.3) : Color.accentBlue.opacity(0.08))
        .cornerRadius(6)
    }

    private var diffSummary: String {
        var lines: [String] = []
        let oldCount = originalColumns.count
        let newCount = editedColumns.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }.count

        for (i, col) in editedColumns.enumerated() {
            let name = col.name.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            if i < oldCount {
                let orig = originalColumns[i]
                var changes: [String] = []
                let qName = "\"\(name)\""
                if name != orig.name {
                    changes.append("rename to \(qName)")
                }
                if col.type != orig.dataType {
                    changes.append("type \(col.type)")
                }
                if col.isNullable != orig.isNullable {
                    changes.append(col.isNullable ? "drop not null" : "set not null")
                }
                let defStr = col.defaultValue.trimmingCharacters(in: .whitespaces)
                let origDef = orig.defaultValue ?? ""
                if defStr != origDef {
                    if defStr.isEmpty {
                        changes.append("drop default")
                    } else {
                        changes.append("default \(defStr)")
                    }
                }
                if !changes.isEmpty {
                    lines.append("ALTER \(qName): \(changes.joined(separator: ", "))")
                }
            } else {
                lines.append("ADD \"\(name)\" \(col.type)")
            }
        }
        for i in oldCount..<originalColumns.count {
            let alreadyMatched = i < editedColumns.count && editedColumns[i].name.trimmingCharacters(in: .whitespaces) == originalColumns[i].name
            if !alreadyMatched {
                lines.append("DROP \"\(originalColumns[i].name)\"")
            }
        }
        return lines.isEmpty ? "-- No changes" : lines.joined(separator: "\n")
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Changes to Apply")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()
                Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(diffSummary, forType: .string) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 10))
                        Text("Copy")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView([.horizontal, .vertical]) {
                Text(diffSummary)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 100)
            .background(Color.bgSecondary)
            .cornerRadius(6)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var footer: some View {
        HStack {
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.accentRed)
            }
            if let msg = successMessage {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundColor(.accentGreen)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.return, modifiers: [])
            } else {
                Spacer()
                Button("Cancel", action: { dismiss() })
                    .keyboardShortcut(.escape, modifiers: [])
                Button(action: applyChanges) {
                    HStack(spacing: 4) {
                        if isApplying {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                        Text("Apply Changes")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(hasChanges ? Color.accentBlue : Color.gray)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!hasChanges || isApplying)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var hasChanges: Bool {
        diffSummary != "-- No changes"
    }

    private func loadColumns() async {
        isLoading = true
        let cols = await databaseService.fetchColumns(configID: configID, table: table)
        originalColumns = cols
        editedColumns = cols.map { col in
            ColumnDef(
                name: col.name,
                type: col.dataType,
                isNullable: col.isNullable,
                isPrimaryKey: col.name.lowercased() == "id" || col.name.hasSuffix("_id"),
                defaultValue: col.defaultValue ?? ""
            )
        }
        isLoading = false
    }

    private func applyChanges() {
        isApplying = true
        errorMessage = nil
        Task {
            do {
                for i in editedColumns.indices {
                    let col = editedColumns[i]
                    let name = col.name.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { continue }

                    if i < originalColumns.count {
                        let orig = originalColumns[i]
                        let defStr = col.defaultValue.trimmingCharacters(in: .whitespaces)
                        let origDef = orig.defaultValue ?? ""
                        let newName = name != orig.name ? name : nil
                        let newType = col.type != orig.dataType ? col.type : nil
                        let newNullable: Bool? = col.isNullable != orig.isNullable ? col.isNullable : nil
                        let newDefault: String? = defStr != origDef ? (defStr.isEmpty ? nil : defStr) : nil
                        if newName != nil || newType != nil || newNullable != nil || newDefault != nil {
                            try await databaseService.alterColumn(
                                configID: configID,
                                table: table,
                                column: orig.name,
                                newName: newName,
                                newType: newType,
                                nullable: newNullable,
                                defaultValue: newDefault
                            )
                        }
                    } else {
                        try await databaseService.addColumn(
                            configID: configID,
                            table: table,
                            column: NewColumnInfo(
                                name: name,
                                type: col.type,
                                isNullable: col.isNullable,
                                defaultValue: col.defaultValue.isEmpty ? nil : col.defaultValue,
                                isPrimaryKey: col.isPrimaryKey
                            )
                        )
                    }
                }
                for i in (editedColumns.count..<originalColumns.count).reversed() {
                    try await databaseService.dropColumn(configID: configID, table: table, column: originalColumns[i].name)
                }
                await MainActor.run {
                    successMessage = "Table updated successfully"
                    isApplying = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isApplying = false
                }
            }
        }
    }
}

private struct ColumnDef {
    var name: String = ""
    var type: String = "text"
    var isNullable: Bool = true
    var isPrimaryKey: Bool = false
    var defaultValue: String = ""
}
