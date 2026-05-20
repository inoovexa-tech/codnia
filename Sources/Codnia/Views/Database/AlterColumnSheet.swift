import SwiftUI

struct AlterColumnSheet: View {
    let configID: String
    let table: TableID
    let column: ColumnInfo?
    let mode: AlterMode

    @EnvironmentObject var databaseService: DatabaseConnectionService
    @Environment(\.dismiss) private var dismiss

    @State private var columnName: String = ""
    @State private var columnType: String = ""
    @State private var isNullable: Bool = true
    @State private var defaultValue: String = ""
    @State private var isAltering = false
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

    enum AlterMode {
        case add
        case alter

        var title: String {
            switch self {
            case .add: return "Add Column"
            case .alter: return "Alter Column"
            }
        }

        var buttonLabel: String {
            switch self {
            case .add: return "Add"
            case .alter: return "Apply"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            formContent
            Divider()
            footer
        }
        .frame(width: 420)
        .onAppear {
            if let col = column {
                columnName = col.name
                columnType = col.dataType
                isNullable = col.isNullable
                defaultValue = col.defaultValue ?? ""
            }
        }
    }

    private var header: some View {
        HStack {
            Text(mode.title)
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
        VStack(alignment: .leading, spacing: 12) {
            Group {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Table")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textTertiary)
                    Text("\(table.schema).\(table.table)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Column Name")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textTertiary)
                    TextField("column_name", text: $columnName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Data Type")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textTertiary)
                    Picker("", selection: $columnType) {
                        ForEach(pgTypes, id: \.self) { t in
                            Text(t).tag(t)
                        }
                    }
                    .labelsHidden()
                }

                Toggle("Nullable", isOn: $isNullable)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Default Value (optional)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textTertiary)
                    TextField("e.g. 0, 'text', now()", text: $defaultValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
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
            Button(action: apply) {
                HStack(spacing: 4) {
                    if isAltering {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                    Text(mode.buttonLabel)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(isFormValid ? Color.accentBlue : Color.gray)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isFormValid || isAltering)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var isFormValid: Bool {
        !columnName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func apply() {
        let name = columnName.trimmingCharacters(in: .whitespaces)
        isAltering = true
        errorMessage = nil

        Task {
            do {
                switch mode {
                case .add:
                    let newCol = NewColumnInfo(
                        name: name,
                        type: columnType,
                        isNullable: isNullable,
                        defaultValue: defaultValue.isEmpty ? nil : defaultValue,
                        isPrimaryKey: false
                    )
                    try await databaseService.addColumn(configID: configID, table: table, column: newCol)
                case .alter:
                    let newName = name != column?.name ? name : nil
                    let newType = columnType != column?.dataType ? columnType : nil
                    let newNullable = isNullable != column?.isNullable ? isNullable : nil as Bool?
                    let newDefault: String?
                    if defaultValue.isEmpty {
                        newDefault = (column?.defaultValue != nil) ? "" : nil
                    } else {
                        newDefault = defaultValue != column?.defaultValue ? defaultValue : nil
                    }
                    try await databaseService.alterColumn(
                        configID: configID,
                        table: table,
                        column: column?.name ?? name,
                        newName: newName,
                        newType: newType,
                        nullable: newNullable,
                        defaultValue: newDefault
                    )
                }
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isAltering = false
                }
            }
        }
    }
}
