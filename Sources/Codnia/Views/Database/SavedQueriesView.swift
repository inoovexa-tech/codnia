import SwiftUI

struct SavedQueryItem: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var sql: String
    var connectionID: String?
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, sql: String, connectionID: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.sql = sql
        self.connectionID = connectionID
        self.createdAt = createdAt
    }
}

@MainActor
class SavedQueriesStore: ObservableObject {
    @Published var queries: [SavedQueryItem] = []

    private let fs = FileSystemService.shared
    private let fileName = "saved-queries.json"

    init() {
        load()
    }

    func add(name: String, sql: String, connectionID: String?) {
        let query = SavedQueryItem(name: name, sql: sql, connectionID: connectionID)
        queries.insert(query, at: 0)
        save()
    }

    func remove(_ id: String) {
        queries.removeAll { $0.id == id }
        save()
    }

    func update(_ item: SavedQueryItem) {
        guard let idx = queries.firstIndex(where: { $0.id == item.id }) else { return }
        queries[idx] = item
        save()
    }

    private func save() {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return }
        let dir = appSupport.appendingPathComponent("Codnia")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName)
        if let data = try? JSONEncoder().encode(queries) {
            try? data.write(to: url)
        }
    }

    private func load() {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }
        let url = appSupport.appendingPathComponent("Codnia").appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([SavedQueryItem].self, from: data)
        else { return }
        queries = items
    }
}

struct SavedQueriesView: View {
    @StateObject private var store = SavedQueriesStore()
    @EnvironmentObject var databaseService: DatabaseConnectionService
    @EnvironmentObject var editorVM: EditorViewModel

    @State private var showNewQuery = false
    @State private var newName = ""
    @State private var newSQL = ""
    @State private var newConnectionID: String?
    @State private var editingItem: SavedQueryItem?
    @State private var showRename = false
    @State private var renameText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text("SAVED QUERIES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textTertiary)

                Spacer()

                Button(action: { showNewQuery = true }) {
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

            if store.queries.isEmpty {
                VStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "bookmark")
                        .font(.system(size: 20))
                        .foregroundColor(.textTertiary)
                    Text("No saved queries")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(store.queries) { item in
                        savedQueryRow(item)
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $showNewQuery) {
            newQuerySheet
        }
        .sheet(isPresented: $showRename) {
            renameSheet
        }
    }

    private func savedQueryRow(_ item: SavedQueryItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentYellow)

                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Spacer()

                Button(action: { openQuery(item) }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.accentGreen)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Open & Run")

                Button(action: {
                    editingItem = item
                    renameText = item.name
                    showRename = true
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 9))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { store.remove(item.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundColor(.accentRed.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
            }

            Text(item.sql.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.textTertiary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            openQuery(item)
        }
    }

    private func openQuery(_ item: SavedQueryItem) {
        let connID = item.connectionID ?? databaseService.connections.first?.id
        let tab = Tab(
            name: item.name,
            type: .queryResult,
            queryConnectionId: connID,
            querySql: item.sql
        )
        editorVM.tabs.append(tab)
        editorVM.querySql[tab.id] = item.sql
        editorVM.activeTabId = tab.id
        editorVM.saveTabsToWorktree()
    }

    private var newQuerySheet: some View {
        VStack(spacing: 16) {
            Text("Save Query")
                .font(.system(size: 14, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 12, weight: .medium))
                TextField("Query name", text: $newName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("SQL")
                    .font(.system(size: 12, weight: .medium))
                TextEditor(text: $newSQL)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.borderDefault))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Connection (optional)")
                    .font(.system(size: 12, weight: .medium))
                Picker("", selection: $newConnectionID) {
                    Text("None").tag(nil as String?)
                    ForEach(databaseService.connections) { config in
                        Text(config.name).tag(config.id as String?)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Button("Cancel") {
                    showNewQuery = false
                    resetNewQuery()
                }
                Spacer()
                Button("Save") {
                    store.add(name: newName, sql: newSQL, connectionID: newConnectionID)
                    showNewQuery = false
                    resetNewQuery()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newName.isEmpty || newSQL.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private var renameSheet: some View {
        VStack(spacing: 16) {
            Text("Rename Query")
                .font(.system(size: 14, weight: .semibold))

            TextField("Name", text: $renameText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    showRename = false
                }
                Spacer()
                Button("Save") {
                    if var item = editingItem {
                        item.name = renameText
                        store.update(item)
                    }
                    showRename = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(renameText.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 300)
    }

    private func resetNewQuery() {
        newName = ""
        newSQL = ""
        newConnectionID = nil
    }
}
