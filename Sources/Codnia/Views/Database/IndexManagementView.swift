import SwiftUI

struct IndexManagementView: View {
    let configID: String
    let table: TableID

    @EnvironmentObject var databaseService: DatabaseConnectionService
    @Environment(\.dismiss) private var dismiss

    @State private var indexes: [IndexInfo] = []
    @State private var isLoading = true
    @State private var showNewIndex = false
    @State private var newIndexName = ""
    @State private var newIndexColumns: Set<String> = []
    @State private var newIndexUnique = false
    @State private var errorMessage: String?
    @State private var isCreating = false
    @State private var columns: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 450, height: 400)
        .task { await loadIndexes() }
        .sheet(isPresented: $showNewIndex) { newIndexSheet }
    }

    private var header: some View {
        HStack {
            Text("Manage Indexes")
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
                    Text("Loading indexes...")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                    Spacer()
                }
            } else if indexes.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "list.number")
                        .font(.system(size: 28))
                        .foregroundColor(.textTertiary)
                    Text("No indexes")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                    Text("Add an index to improve query performance")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(indexes) { idx in
                        indexRow(idx)
                    }
                    .onDelete { offsets in
                        for offset in offsets {
                            let idx = indexes[offset]
                            Task { await dropIndex(idx) }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func indexRow(_ idx: IndexInfo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: idx.isUnique ? "lock" : "list.number")
                .font(.system(size: 11))
                .foregroundColor(idx.isUnique ? .accentYellow : .accentBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text(idx.name)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.textPrimary)
                Text("(\(idx.columns.joined(separator: ", ")))\(idx.isUnique ? " UNIQUE" : "")")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
            }

            Spacer()

            Button(action: {
                Task { await dropIndex(idx) }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(.accentRed)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }

    private var footer: some View {
        HStack {
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.accentRed)
            }
            Spacer()
            Button(action: { showNewIndex = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                    Text("New Index")
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

    private var newIndexSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Index")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { showNewIndex = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Index Name")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textTertiary)
                    TextField("idx_column_name", text: $newIndexName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }

                Toggle("Unique", isOn: $newIndexUnique)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Columns")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textTertiary)
                    if columns.isEmpty {
                        Text("Loading columns...")
                            .font(.system(size: 11))
                            .foregroundColor(.textTertiary)
                    } else {
                        ForEach(columns, id: \.self) { col in
                            Toggle(col, isOn: Binding(
                                get: { newIndexColumns.contains(col) },
                                set: { isOn in
                                    if isOn { newIndexColumns.insert(col) }
                                    else { newIndexColumns.remove(col) }
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12, design: .monospaced))
                        }
                    }
                }
            }
            .padding(16)

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { showNewIndex = false }
                    .keyboardShortcut(.escape, modifiers: [])
                Button(action: createIndex) {
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
        .frame(width: 380, height: 400)
        .task {
            let cols = await databaseService.fetchColumns(configID: configID, table: table)
            columns = cols.map(\.name)
        }
    }

    private var canCreate: Bool {
        !newIndexName.trimmingCharacters(in: .whitespaces).isEmpty && !newIndexColumns.isEmpty
    }

    private func loadIndexes() async {
        isLoading = true
        indexes = await databaseService.fetchIndexes(configID: configID, table: table)
        isLoading = false
    }

    private func dropIndex(_ idx: IndexInfo) async {
        errorMessage = nil
        do {
            try await databaseService.dropIndex(configID: configID, indexName: idx.name, table: table)
            await loadIndexes()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func createIndex() {
        let name = newIndexName.trimmingCharacters(in: .whitespaces)
        isCreating = true
        errorMessage = nil
        Task {
            do {
                try await databaseService.createIndex(
                    configID: configID,
                    table: table,
                    name: name,
                    columns: Array(newIndexColumns).sorted(),
                    unique: newIndexUnique
                )
                await MainActor.run {
                    showNewIndex = false
                    newIndexName = ""
                    newIndexColumns = []
                    newIndexUnique = false
                }
                await loadIndexes()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}
