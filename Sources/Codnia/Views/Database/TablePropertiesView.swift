import SwiftUI

struct TablePropertiesView: View {
    let configID: String
    let table: TableID

    @EnvironmentObject var databaseService: DatabaseConnectionService
    @Environment(\.dismiss) private var dismiss

    @State private var properties: TableProperties?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if isLoading {
                loadingState
            } else if let error = errorMessage {
                errorState(error)
            } else if let props = properties {
                content(props)
            }
            Divider()
            footer
        }
        .frame(width: 520, height: 560)
        .task { await loadProperties() }
    }

    private var header: some View {
        HStack {
            Image(systemName: "tablecells")
                .font(.system(size: 12))
                .foregroundColor(.accentBlue)
            Text("Table Properties")
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

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
            Text("Loading properties...")
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)
            Spacer()
        }
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(.accentRed)
            Text("Failed to load properties")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
            Text(error)
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Close", action: { dismiss() })
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func content(_ props: TableProperties) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                overviewSection(props)
                Divider()
                columnsSection(props)
                Divider()
                indexesSection(props)
                if !props.triggers.isEmpty {
                    Divider()
                    triggersSection(props)
                }
                if let ddl = props.ddl {
                    Divider()
                    ddlSection(ddl)
                }
            }
        }
    }

    // MARK: - Overview

    private func overviewSection(_ props: TableProperties) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Overview")

            VStack(spacing: 6) {
                overviewRow("Schema", value: props.table.schema)
                overviewRow("Name", value: props.table.name)
                overviewRow("Type", value: props.table.tableType.rawValue)

                if let stats = props.stats {
                    if let count = stats.estimatedRowCount {
                        overviewRow("Row Estimate", value: formatNumber(count))
                    }
                    if let totalSize = stats.totalSize {
                        overviewRow("Total Size", value: totalSize)
                    }
                    if let tableSize = stats.tableSize {
                        overviewRow("Table Size", value: tableSize)
                    }
                    if let indexSize = stats.indexSize {
                        overviewRow("Index Size", value: indexSize)
                    }
                    if let owner = stats.tableOwner {
                        overviewRow("Owner", value: owner)
                    }
                    if let comment = stats.tableComment, !comment.isEmpty {
                        overviewRow("Comment", value: comment)
                    }
                    if let vac = stats.lastVacuum {
                        overviewRow("Last Vacuum", value: vac)
                    }
                    if let ana = stats.lastAnalyze {
                        overviewRow("Last Analyze", value: ana)
                    }
                }
            }
        }
        .padding(12)
    }

    private func overviewRow(_ label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textTertiary)
                .frame(width: 100, alignment: .trailing)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.textPrimary)
                .textSelection(.enabled)
            Spacer()
        }
    }

    // MARK: - Columns

    private func columnsSection(_ props: TableProperties) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Columns (\(props.columns.count))")

            ForEach(props.columns) { col in
                HStack(spacing: 8) {
                    let isPK = props.primaryKeys.contains(col.name)
                    Image(systemName: isPK ? "key.fill" : "text.alignleft")
                        .font(.system(size: 9))
                        .foregroundColor(isPK ? .accentYellow : .textTertiary)
                        .frame(width: 12)

                    Text(col.name)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.textPrimary)
                        .frame(width: 130, alignment: .leading)
                        .lineLimit(1)

                    Text(col.dataType)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.accentBlue)

                    Spacer()

                    if !col.isNullable {
                        Text("NOT NULL")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.textTertiary)
                    }

                    if let def = col.defaultValue, !def.isEmpty {
                        Text(def)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.textTertiary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
    }

    // MARK: - Indexes

    private func indexesSection(_ props: TableProperties) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Indexes (\(props.indexes.count))")

            if props.indexes.isEmpty {
                Text("No indexes")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
            } else {
                ForEach(props.indexes) { idx in
                    HStack(spacing: 8) {
                        Image(systemName: idx.isUnique ? "lock" : "list.number")
                            .font(.system(size: 10))
                            .foregroundColor(idx.isUnique ? .accentYellow : .accentBlue)
                            .frame(width: 12)

                        Text(idx.name)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.textPrimary)

                        Text("(\(idx.columns.joined(separator: ", ")))")
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)

                        if idx.isUnique {
                            Text("UNIQUE")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.accentYellow)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
    }

    // MARK: - Triggers

    private func triggersSection(_ props: TableProperties) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Triggers (\(props.triggers.count))")

            ForEach(props.triggers) { trig in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt")
                            .font(.system(size: 10))
                            .foregroundColor(.accentYellow)
                            .frame(width: 12)
                        Text(trig.name)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.textPrimary)
                        Spacer()
                    }
                    if let def = trig.definition {
                        Text(def)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.textTertiary)
                            .lineLimit(3)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
    }

    // MARK: - DDL

    private func ddlSection(_ ddl: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("DDL")

            ScrollView(.horizontal, showsIndicators: true) {
                Text(ddl)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .padding(8)
            .background(Color.bgSecondary)
            .cornerRadius(6)
        }
        .padding(12)
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.textSecondary)
            .textCase(.uppercase)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            let m = Double(n) / 1_000_000
            return String(format: "%.1fM", m)
        } else if n >= 1_000 {
            let k = Double(n) / 1_000
            return String(format: "%.1fK", k)
        }
        return "\(n)"
    }

    private func loadProperties() async {
        isLoading = true
        errorMessage = nil
        let props = await databaseService.fetchTableProperties(configID: configID, table: table)
        if props.columns.isEmpty && props.ddl == nil {
            await MainActor.run {
                errorMessage = "Could not load table properties"
                isLoading = false
            }
        } else {
            await MainActor.run {
                properties = props
                isLoading = false
            }
        }
    }
}
