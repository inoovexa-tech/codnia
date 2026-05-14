import SwiftUI

struct QueryResultTabView: View {
    let tabId: String

    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var databaseService: DatabaseConnectionService

    @State private var sql: String = ""
    @State private var selectedText: String = ""
    @State private var isExecuting = false
    @State private var selectedConnectionId: String?
    @State private var showConnectionPicker = false
    @State private var editorHeight: CGFloat = 56
    @State private var editorMaxHeight: CGFloat = 400
    @State private var sortColumn: String? = nil
    @State private var sortAscending: Bool = true
    @State private var currentPageSize: Int = 100

    private var connectedConfigs: [ConnectionConfig] {
        databaseService.connections.filter {
            databaseService.state(for: $0.id).isConnected
        }
    }

    private var computedEditorHeight: CGFloat {
        let lines = max(1, sql.components(separatedBy: "\n").count)
        let wrapped = max(0, (sql.count - 80 * max(0, lines - 1) + 79) / 80)
        let total = lines + wrapped
        return min(max(56, CGFloat(total) * 20 + 12), editorMaxHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            sqlEditor
                .frame(height: max(computedEditorHeight, editorHeight))

            DraggableDivider(value: $editorHeight, minValue: 56, maxValue: editorMaxHeight)

            Divider()

            if let result = editorVM.queryResults[tabId] {
                PaginatedDataGridView(
                    columns: result.columns,
                    columnTypes: result.columnTypes,
                    rows: result.rows,
                    page: result.page,
                    pageSize: result.pageSize,
                    totalCount: result.totalCount,
                    executionTime: result.executionTime,
                    error: result.error,
                    isLoading: isExecuting,
                    sortColumn: sortColumn,
                    sortAscending: sortAscending,
                    onPageChange: { newPage, newPageSize in
                        currentPageSize = newPageSize
                        executeQuery(page: newPage, pageSize: newPageSize, sortColumn: sortColumn, sortAscending: sortAscending)
                    },
                    onSortChange: { col, asc in
                        sortColumn = col
                        sortAscending = asc
                        executeQuery(page: 0, pageSize: currentPageSize, sortColumn: col, sortAscending: asc)
                    }
                )
            } else {
                emptyResultState
            }
        }
        .onAppear {
            loadSavedSQL()
            autoSelectConnection()
            if editorVM.queryResults[tabId] == nil,
               !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               selectedConnectionId != nil {
                executeQuery()
            }
            editorHeight = computedEditorHeight
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            connectionPicker

            Spacer()

            HStack(spacing: 4) {
                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                }

                Button(action: { executeQuery() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                        Text("Run")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.accentGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentGreen.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(isExecuting || selectedConnectionId == nil)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }

    private var connectionPicker: some View {
        Menu {
            ForEach(databaseService.connections) { config in
                Button {
                    selectedConnectionId = config.id
                } label: {
                    HStack {
                        Circle()
                            .fill(connectionStateColor(config.id))
                            .frame(width: 6, height: 6)
                        Text(config.name)
                        if config.id == selectedConnectionId {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(connectionStateColor(selectedConnectionId))
                    .frame(width: 6, height: 6)
                Text(selectedConnectionName)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
                    .foregroundColor(.textTertiary)
            }
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .buttonStyle(PlainButtonStyle())
    }

    private var selectedConnectionName: String {
        guard let id = selectedConnectionId,
              let config = databaseService.config(withID: id)
        else { return "Select connection" }
        return config.name
    }

    private func connectionStateColor(_ id: String?) -> Color {
        guard let id = id else { return .textTertiary }
        switch databaseService.state(for: id) {
        case .connected: return .accentGreen
        case .connecting: return .accentYellow
        case .disconnected: return .textTertiary
        case .error: return .accentRed
        }
    }

    // MARK: - SQL Editor

    private var sqlEditor: some View {
        SQLTextEditor(text: $sql, onSelectionChange: { sel in
            selectedText = sel
        })
        .padding(.horizontal, 4)
        .onChange(of: sql) { newValue in
            editorVM.querySql[tabId] = newValue
        }
    }

    // MARK: - Empty State

    private var emptyResultState: some View {
        VStack(spacing: 8) {
            Spacer()

            if isExecuting {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Executing query...")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
            } else {
                Image(systemName: "text.cursor")
                    .font(.system(size: 32))
                    .foregroundColor(.textTertiary)

                Text("Write your SQL query above and press Run")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)

                Text("Command + Enter to execute")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary.opacity(0.6))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }

    // MARK: - Actions

    private func executeQuery(page: Int = 0, pageSize: Int = 100, sortColumn: String? = nil, sortAscending: Bool = true) {
        guard let connectionId = selectedConnectionId else { return }

        let query: String
        if !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query = selectedText
        } else if !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query = sql
        } else {
            return
        }

        let orderBy = sortColumn.map { col -> String in
            let direction = sortAscending ? "ASC" : "DESC"
            let escaped = col.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\" \(direction)"
        }

        isExecuting = true
        print("[QueryResultTabView] executeQuery page=\(page) pageSize=\(pageSize) orderBy=\(orderBy ?? "nil")")

        Task { @MainActor in
            let result = await databaseService.execute(configID: connectionId, sql: query, page: page, pageSize: pageSize, orderBy: orderBy)
            print("[QueryResultTabView] result received page=\(result.page) rows=\(result.rows.count) totalCount=\(result.totalCount) error=\(result.error ?? "nil")")
            editorVM.setQueryResult(result, forTab: tabId)
            editorVM.activeTabId = tabId

            // Tab name intentionally left unchanged to preserve user-given name

            isExecuting = false
        }
    }

    private func loadSavedSQL() {
        if let saved = editorVM.querySql[tabId] {
            sql = saved
        } else if let tab = editorVM.tabs.first(where: { $0.id == tabId }), let saved = tab.querySql {
            sql = saved
            editorVM.querySql[tabId] = saved
        }
    }

    private func autoSelectConnection() {
        if let tab = editorVM.tabs.first(where: { $0.id == tabId }),
           let connId = tab.queryConnectionId,
           databaseService.connections.contains(where: { $0.id == connId }) {
            selectedConnectionId = connId
        } else if connectedConfigs.count == 1 {
            selectedConnectionId = connectedConfigs[0].id
        } else if databaseService.connections.count == 1 {
            selectedConnectionId = databaseService.connections[0].id
        }
    }

    private func executeIfPreloaded() {
        guard editorVM.queryResults[tabId] == nil else { return }
        if !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedConnectionId != nil {
            executeQuery()
        }
    }
}
