import SwiftUI

struct DependenciesView: View {
    let configID: String
    let table: TableID

    @EnvironmentObject var databaseService: DatabaseConnectionService
    @Environment(\.dismiss) private var dismiss

    @State private var dependents: [String] = []
    @State private var references: [(columns: [String], refTable: String, refColumns: [String])] = []
    @State private var referencedBy: [(table: String, columns: [String], refColumns: [String])] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 520, height: 480)
        .task { await loadData() }
    }

    private var header: some View {
        HStack {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12))
                .foregroundColor(.accentBlue)
            Text("Dependencies")
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
                    Text("Loading dependencies...")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                    Spacer()
                }
            } else if references.isEmpty && referencedBy.isEmpty && dependents.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 28))
                        .foregroundColor(.textTertiary)
                    Text("No dependencies found")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                    Text("This table has no foreign key relationships")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        if !references.isEmpty {
                            relationshipSection(
                                title: "References",
                                subtitle: "Tables this table points to via FK",
                                icon: "arrow.right",
                                color: .accentBlue
                            ) {
                                ForEach(references.indices, id: \.self) { i in
                                    let ref = references[i]
                                    HStack(spacing: 8) {
                                        Text("\(table.table)(\(ref.columns.joined(separator: ", ")))")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.textPrimary)
                                        Text("→")
                                            .font(.system(size: 10))
                                            .foregroundColor(.textTertiary)
                                        Text("\(ref.refTable)(\(ref.refColumns.joined(separator: ", ")))")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.accentBlue)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                }
                            }
                            Divider()
                        }

                        if !referencedBy.isEmpty {
                            relationshipSection(
                                title: "Referenced By",
                                subtitle: "Tables that have FK pointing to this table",
                                icon: "arrow.left",
                                color: .accentOrange
                            ) {
                                ForEach(referencedBy, id: \.table) { ref in
                                    HStack(spacing: 8) {
                                        Text("\(ref.table)(\(ref.columns.joined(separator: ", ")))")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.accentOrange)
                                        Text("→")
                                            .font(.system(size: 10))
                                            .foregroundColor(.textTertiary)
                                        Text("\(table.table)(\(ref.refColumns.joined(separator: ", ")))")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.textPrimary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                }
                            }
                            Divider()
                        }

                        if !dependents.isEmpty {
                            relationshipSection(
                                title: "Used By",
                                subtitle: "Other objects (views, etc.) that depend on this table",
                                icon: "square.fill",
                                color: .accentGreen
                            ) {
                                ForEach(dependents, id: \.self) { dep in
                                    HStack(spacing: 8) {
                                        Image(systemName: "square.fill")
                                            .font(.system(size: 6))
                                            .foregroundColor(.accentGreen)
                                        Text(dep)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.textPrimary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func relationshipSection<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            Text(subtitle)
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
                .padding(.horizontal, 16)
            content()
        }
        .padding(.bottom, 8)
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

    private func loadData() async {
        isLoading = true

        async let deps = databaseService.fetchDependencies(configID: configID, schema: table.schema, table: table.table)
        async let allFKs = databaseService.fetchForeignKeys(configID: configID, schema: table.schema)

        let (depsResult, fkResult) = await (deps, allFKs)

        var fwd: [(columns: [String], refTable: String, refColumns: [String])] = []
        var rev: [(table: String, columns: [String], refColumns: [String])] = []

        for fk in fkResult {
            if fk.schema == table.schema && fk.table == table.table {
                let existingIndex = fwd.firstIndex(where: { $0.refTable == fk.foreignTable })
                if let idx = existingIndex {
                    fwd[idx].columns.append(fk.column)
                    fwd[idx].refColumns.append(fk.foreignColumn)
                } else {
                    fwd.append((
                        columns: [fk.column],
                        refTable: fk.foreignTable,
                        refColumns: [fk.foreignColumn]
                    ))
                }
            }
            if fk.foreignSchema == table.schema && fk.foreignTable == table.table {
                let existingIndex = rev.firstIndex(where: { $0.table == fk.table })
                if let idx = existingIndex {
                    rev[idx].columns.append(fk.column)
                    rev[idx].refColumns.append(fk.foreignColumn)
                } else {
                    rev.append((
                        table: fk.table,
                        columns: [fk.column],
                        refColumns: [fk.foreignColumn]
                    ))
                }
            }
        }

        await MainActor.run {
            dependents = depsResult
            references = fwd
            referencedBy = rev
            isLoading = false
        }
    }
}
