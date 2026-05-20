import SwiftUI

struct CreateTableSheet: View {
    let configID: String
    let schema: String

    @EnvironmentObject var databaseService: DatabaseConnectionService
    @Environment(\.dismiss) private var dismiss

    @State private var tableName = ""
    @State private var columns: [ColumnDef] = [ColumnDef()]
    @State private var isCreating = false
    @State private var errorMessage: String?

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

    private var sqlPreview: String {
        guard !tableName.trimmingCharacters(in: .whitespaces).isEmpty else { return "-- Enter a table name" }
        let validCols = columns.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !validCols.isEmpty else { return "-- Add at least one column" }
        var defs: [String] = []
        var pkCols: [String] = []
        for col in validCols {
            var def = "\"\(col.name)\" \(col.type)"
            if !col.isNullable { def += " NOT NULL" }
            if !col.defaultValue.isEmpty { def += " DEFAULT \(col.defaultValue)" }
            if col.isPrimaryKey { pkCols.append("\"\(col.name)\"") }
            defs.append("  \(def)")
        }
        if !pkCols.isEmpty {
            defs.append("  PRIMARY KEY (\(pkCols.joined(separator: ", ")))")
        }
        return "CREATE TABLE \"\(schema)\".\"\(tableName)\" (\n\(defs.joined(separator: ",\n"))\n);"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            formContent
            Divider()
            previewSection
            Divider()
            footer
        }
        .frame(width: 520, height: 600)
    }

    private var header: some View {
        HStack {
            Text("Create Table")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
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
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Schema")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textTertiary)
                        Text(schema)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Table Name")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textTertiary)
                        TextField("my_table", text: $tableName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(width: 200)
                    }
                }

                Divider()

                HStack {
                    Text("Columns")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Button(action: { columns.append(ColumnDef()) }) {
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

                ForEach(columns.indices, id: \.self) { idx in
                    columnRow(idx)
                }
            }
            .padding(16)
        }
    }

    private func columnRow(_ idx: Int) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                TextField("name", text: Binding(
                    get: { columns[idx].name },
                    set: { columns[idx].name = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 130)

                Picker("", selection: Binding(
                    get: { columns[idx].type },
                    set: { columns[idx].type = $0 }
                )) {
                    ForEach(pgTypes, id: \.self) { t in
                        Text(t).tag(t)
                    }
                }
                .labelsHidden()
                .frame(width: 150)

                if columns.count > 1 {
                    Button(action: { columns.remove(at: idx) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.accentRed)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            HStack(spacing: 12) {
                Toggle("Nullable", isOn: Binding(
                    get: { columns[idx].isNullable },
                    set: { columns[idx].isNullable = $0 }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)

                Toggle("PK", isOn: Binding(
                    get: { columns[idx].isPrimaryKey },
                    set: { columns[idx].isPrimaryKey = $0 }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)

                TextField("Default (optional)", text: Binding(
                    get: { columns[idx].defaultValue },
                    set: { columns[idx].defaultValue = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 180)
            }
        }
        .padding(8)
        .background(Color.bgHover.opacity(0.3))
        .cornerRadius(6)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("SQL Preview")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()
                Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(sqlPreview, forType: .string) }) {
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
                Text(sqlPreview)
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
            Spacer()
            Button("Cancel", action: { dismiss() })
                .keyboardShortcut(.escape, modifiers: [])
            Button(action: createTable) {
                HStack(spacing: 4) {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                    Text("Create")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(isValid ? Color.accentBlue : Color.gray)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isValid || isCreating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var isValid: Bool {
        let name = tableName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return false }
        let validCols = columns.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !validCols.isEmpty else { return false }
        return true
    }

    private func createTable() {
        let name = tableName.trimmingCharacters(in: .whitespaces)
        let newColumns = columns
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { col in
                NewColumnInfo(
                    name: col.name.trimmingCharacters(in: .whitespaces),
                    type: col.type,
                    isNullable: col.isNullable,
                    defaultValue: col.defaultValue.isEmpty ? nil : col.defaultValue,
                    isPrimaryKey: col.isPrimaryKey
                )
            }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                try await databaseService.createTable(configID: configID, schema: schema, name: name, columns: newColumns)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
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
