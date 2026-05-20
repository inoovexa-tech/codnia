import SwiftUI

struct QueryResultTabView: View {
    let tabId: String

    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var databaseService: DatabaseConnectionService

    @State private var sql: String = ""
    @State private var selectedText: String = ""
    @State private var isExecuting = false
    @State private var isApplying = false
    @State private var selectedConnectionId: String?
    @State private var showConnectionPicker = false
    @State private var editorHeight: CGFloat = 56
    @State private var editorMaxHeight: CGFloat = 400
    @State private var sortColumn: String? = nil
    @State private var sortAscending: Bool = true
    @State private var currentPageSize: Int = 100
    @State private var selectedRow: Int?
    @State private var stagedEdits: [String: String] = [:]
    @State private var stagedNewRows: [StagedNewRow] = []
    @State private var stagedDeletions: Set<Int> = []
    @State private var applyError: String?

    private var connectedConfigs: [ConnectionConfig] {
        databaseService.connections.filter {
            databaseService.state(for: $0.id).isConnected
        }
    }

    private var tableId: TableID? {
        guard let tab = editorVM.tabs.first(where: { $0.id == tabId }),
              let schema = tab.queryTableSchema,
              let table = tab.queryTableName
        else { return nil }
        return TableID(schema: schema, table: table)
    }

    private var isTableEditable: Bool {
        tableId != nil && selectedConnectionId != nil
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
                    error: applyError ?? result.error,
                    isLoading: isExecuting,
                    sortColumn: sortColumn,
                    sortAscending: sortAscending,
                    onPageChange: { newPage, newPageSize in
                        selectedRow = nil
                        currentPageSize = newPageSize
                        executeQuery(page: newPage, pageSize: newPageSize, sortColumn: sortColumn, sortAscending: sortAscending)
                    },
                    onSortChange: { col, asc in
                        selectedRow = nil
                        sortColumn = col
                        sortAscending = asc
                        executeQuery(page: 0, pageSize: currentPageSize, sortColumn: col, sortAscending: asc)
                    },
                    isEditable: isTableEditable,
                    selectedRow: $selectedRow,
                    stagedEdits: $stagedEdits,
                    stagedNewRows: $stagedNewRows,
                    stagedDeletions: $stagedDeletions,
                    onApplyChanges: { applyChanges() },
                    onDiscardChanges: {
                        stagedEdits = [:]
                        stagedNewRows = []
                        stagedDeletions = []
                        applyError = nil
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

            if isTableEditable {
                Button(action: addNewRow) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.square")
                            .font(.system(size: 11))
                        Text("Add Row")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.accentGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentGreen.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()

            HStack(spacing: 4) {
                if isExecuting || isApplying {
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

    // MARK: - Staged Operations

    private func addNewRow() {
        guard let result = editorVM.queryResults[tabId] else { return }
        var values: [String?] = Array(repeating: nil, count: result.columns.count)
        for i in 0..<min(result.columns.count, result.columnTypes.count) {
            let colName = result.columns[i].lowercased()
            let colType = result.columnTypes[i].lowercased()
            let isSerial = colType.contains("serial")
            let isUUID = colType.contains("uuid")
            let isId = colName == "id" || colName.hasSuffix("_id") || colName == "codigo" || colName == "cod"
            let isDate = colType.contains("date") || colType.contains("timestamp") || colType.contains("timestamptz")
            if isSerial || isUUID || isId {
                values[i] = "[auto]"
            } else if isDate {
                let now = Date()
                if colType.contains("timestamp") || colType.contains("timestamptz") {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    values[i] = f.string(from: now)
                } else if colType.contains("date") {
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd"
                    values[i] = f.string(from: now)
                } else {
                    let f = DateFormatter()
                    f.dateFormat = "HH:mm:ss"
                    values[i] = f.string(from: now)
                }
            }
        }
        stagedNewRows.append(StagedNewRow(insertAfter: Int.max, values: values))
    }

    private func applyChanges() {
        guard let tableId = tableId,
              let connectionId = selectedConnectionId,
              let result = editorVM.queryResults[tabId]
        else { return }

        isApplying = true
        applyError = nil

        Task { @MainActor in
            let pkCols = await databaseService.fetchPrimaryKeyColumns(configID: connectionId, table: tableId)
            var updatedRows = result.rows

            // 1. Process deletions (from highest index to lowest to preserve indices)
            for rowIdx in stagedDeletions.sorted().reversed() {
                guard rowIdx < updatedRows.count else { continue }
                let row = updatedRows[rowIdx]
                var pkValues: [(column: String, value: String?)] = []
                for pk in pkCols {
                    if let pkIdx = result.columns.firstIndex(of: pk) {
                        pkValues.append((pk, pkIdx < row.count ? row[pkIdx] : nil))
                    }
                }
                if pkValues.isEmpty { continue }
                let affected = await databaseService.deleteRow(configID: connectionId, table: tableId, primaryKeyValues: pkValues)
                if affected > 0 {
                    updatedRows.remove(at: rowIdx)
                }
            }

            // 2. Process updates (apply edits to local rows)
            let editedRowIndices = Set(stagedEdits.keys.compactMap { key -> Int? in
                let parts = key.split(separator: ":")
                guard parts.count == 2, let row = Int(parts[0]) else { return nil }
                return row
            })

            for rowIdx in editedRowIndices {
                guard rowIdx < updatedRows.count else { continue }
                let oldRow = updatedRows[rowIdx]

                var pkValues: [(column: String, value: String?)] = []
                for pk in pkCols {
                    if let pkIdx = result.columns.firstIndex(of: pk) {
                        pkValues.append((pk, pkIdx < oldRow.count ? oldRow[pkIdx] : nil))
                    }
                }
                if pkValues.isEmpty { continue }

                var setValues: [(column: String, value: String?)] = []
                for colIdx in 0..<result.columns.count {
                    let key = "\(rowIdx):\(colIdx)"
                    if let newVal = stagedEdits[key] {
                        setValues.append((result.columns[colIdx], newVal.isEmpty ? nil : newVal))
                    }
                }
                if setValues.isEmpty { continue }
                let affected = await databaseService.updateRow(configID: connectionId, table: tableId, set: setValues, primaryKeyValues: pkValues)

                // Update local row on success
                if affected > 0 {
                    var mutatedRow = updatedRows[rowIdx]
                    for colIdx in 0..<result.columns.count {
                        let key = "\(rowIdx):\(colIdx)"
                        if let newVal = stagedEdits[key] {
                            if colIdx < mutatedRow.count {
                                mutatedRow[colIdx] = newVal.isEmpty ? nil : newVal
                            }
                        }
                    }
                    updatedRows[rowIdx] = mutatedRow
                }
            }

            // 3. Process new rows — insert and capture RETURNING values
            var insertFailed = false
            for newRow in stagedNewRows {
                var insertCols: [String] = []
                var insertVals: [String?] = []
                for colIdx in 0..<result.columns.count {
                    let val = colIdx < newRow.values.count ? newRow.values[colIdx] : nil
                    if val == "[auto]" { continue }
                    insertCols.append(result.columns[colIdx])
                    insertVals.append(val)
                }
                guard !insertCols.isEmpty else { continue }

                do {
                    if let inserted = try await databaseService.insertRow(configID: connectionId, table: tableId, columns: insertCols, values: insertVals) {
                        var completeRow: [String?] = Array(repeating: nil, count: result.columns.count)
                        for (colName, val) in inserted {
                            if let idx = result.columns.firstIndex(of: colName) {
                                completeRow[idx] = val
                            }
                        }
                        updatedRows.append(completeRow)
                    }
                } catch {
                    applyError = error.localizedDescription
                    insertFailed = true
                    break
                }
            }

            if insertFailed {
                isApplying = false
                return
            }

            // Clear staged changes
            stagedEdits = [:]
            stagedNewRows = []
            stagedDeletions = []
            selectedRow = nil

            isApplying = false

            reexecuteQuery()
        }
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

        Task { @MainActor in
            let result = await databaseService.execute(configID: connectionId, sql: query, page: page, pageSize: pageSize, orderBy: orderBy)
            editorVM.setQueryResult(result, forTab: tabId)
            editorVM.activeTabId = tabId

            isExecuting = false
        }
    }

    private func reexecuteQuery() {
        executeQuery(page: 0, pageSize: currentPageSize, sortColumn: sortColumn, sortAscending: sortAscending)
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
}
