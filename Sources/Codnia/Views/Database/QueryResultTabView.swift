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
    @State private var executingTask: Task<Void, Never>? = nil
    @State private var showHistory = false

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

    private var currentConnectionName: String {
        guard let id = selectedConnectionId,
              let config = databaseService.config(withID: id)
        else { return "Unknown" }
        return config.name
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

            if showHistory {
                historyPanel
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
                if isExecuting {
                    cancelButton
                } else {
                    runButton
                }

                exportMenu
            }

            historyToggle
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }

    private var runButton: some View {
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

    private var cancelButton: some View {
        Button(action: { cancelQuery() }) {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                Text("Cancel")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.accentRed)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentRed.opacity(0.1))
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
        .keyboardShortcut(.escape, modifiers: [])
    }

    private var exportMenu: some View {
        Menu {
            Button(action: { copyAsCSV() }) {
                Label("Copy as CSV", systemImage: "doc.on.clipboard")
            }
            Button(action: { copyAsJSON() }) {
                Label("Copy as JSON", systemImage: "doc.on.clipboard")
            }
            Divider()
            Button(action: { saveAsCSV() }) {
                Label("Save as CSV...", systemImage: "doc")
            }
            Button(action: { saveAsJSON() }) {
                Label("Save as JSON...", systemImage: "doc")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11))
                Text("Export")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.bgHover)
            .cornerRadius(4)
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .buttonStyle(PlainButtonStyle())
        .disabled(editorVM.queryResults[tabId] == nil || editorVM.queryResults[tabId]?.columns.isEmpty == true)
    }

    private var historyToggle: some View {
        Button(action: { showHistory.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: showHistory ? "clock.fill" : "clock")
                    .font(.system(size: 11))
                Text("History")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(showHistory ? .accentBlue : .textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(showHistory ? Color.accentBlue.opacity(0.1) : Color.bgHover)
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
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

    // MARK: - History Panel

    private var historyPanel: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text("Query History")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()
                Text("\(editorVM.queryHistory[tabId]?.count ?? 0)")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.bgSecondary)

            if (editorVM.queryHistory[tabId]?.isEmpty ?? true) {
                VStack(spacing: 4) {
                    Text("No queries yet")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(editorVM.queryHistory[tabId]!) { item in
                        historyRow(item)
                    }
                }
                .listStyle(.plain)
                .frame(height: min(CGFloat(editorVM.queryHistory[tabId]?.count ?? 0) * 44, 200))
            }
        }
    }

    private func historyRow(_ item: QueryHistoryItem) -> some View {
        Button(action: {
            sql = item.sql
            editorVM.querySql[tabId] = item.sql
            showHistory = false
        }) {
            HStack(spacing: 8) {
                Circle()
                    .fill(item.isError ? Color.accentRed : Color.accentGreen)
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.sql.replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(item.connectionName)
                            .font(.system(size: 9))
                            .foregroundColor(.textTertiary)
                        Text(formattedTimestamp(item.timestamp))
                            .font(.system(size: 9))
                            .foregroundColor(.textTertiary)
                        Text(String(format: "%.0fms", item.duration * 1000))
                            .font(.system(size: 9))
                            .foregroundColor(.textTertiary)
                        if item.rowCount > 0 {
                            Text("\(item.rowCount) rows")
                                .font(.system(size: 9))
                                .foregroundColor(.textTertiary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.doc.on.clipboard")
                    .font(.system(size: 9))
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
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

        let task = Task { @MainActor in
            let start = Date()
            let result = await databaseService.execute(configID: connectionId, sql: query, page: page, pageSize: pageSize, orderBy: orderBy)
            let duration = Date().timeIntervalSince(start)

            guard !Task.isCancelled else {
                isExecuting = false
                return
            }

            editorVM.setQueryResult(result, forTab: tabId)
            editorVM.activeTabId = tabId

            editorVM.addQueryHistory(
                forTab: tabId,
                sql: query,
                connectionName: currentConnectionName,
                duration: duration,
                rowCount: result.rows.count,
                isError: result.error != nil
            )

            isExecuting = false
            executingTask = nil
        }

        executingTask = task
    }

    private func cancelQuery() {
        executingTask?.cancel()
        executingTask = nil
        isExecuting = false

        guard let connectionId = selectedConnectionId else { return }
        Task {
            await databaseService.cancelExecution(configID: connectionId)
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

    // MARK: - Export

    private func copyAsCSV() {
        guard let result = editorVM.queryResults[tabId] else { return }
        let csv = generateCSV(columns: result.columns, rows: result.rows)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(csv, forType: .string)
    }

    private func copyAsJSON() {
        guard let result = editorVM.queryResults[tabId] else { return }
        let json = generateJSON(columns: result.columns, rows: result.rows)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
    }

    private func saveAsCSV() {
        guard let result = editorVM.queryResults[tabId] else { return }
        let csv = generateCSV(columns: result.columns, rows: result.rows)
        saveToFile(content: csv, filename: "query_result.csv")
    }

    private func saveAsJSON() {
        guard let result = editorVM.queryResults[tabId] else { return }
        let json = generateJSON(columns: result.columns, rows: result.rows)
        saveToFile(content: json, filename: "query_result.json")
    }

    private func generateCSV(columns: [String], rows: [[String?]]) -> String {
        var csv = columns.map { escapeCSV($0) }.joined(separator: ",") + "\n"
        for row in rows {
            csv += row.map { escapeCSV($0 ?? "") }.joined(separator: ",") + "\n"
        }
        return csv
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private func generateJSON(columns: [String], rows: [[String?]]) -> String {
        let objects: [[String: String?]] = rows.map { row in
            var dict: [String: String?] = [:]
            for (i, col) in columns.enumerated() {
                dict[col] = i < row.count ? row[i] : nil
            }
            return dict
        }
        guard let data = try? JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .withoutEscapingSlashes]),
              let json = String(data: data, encoding: .utf8)
        else { return "[]" }
        return json
    }

    private func saveToFile(content: String, filename: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
        panel.close()
    }
}
