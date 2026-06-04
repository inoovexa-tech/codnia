import SwiftUI

struct StagedNewRow {
    let insertAfter: Int
    var values: [String?]
}

private struct RowMeta: Equatable {
    let isNew: Bool
    let sourceIndex: Int
}

struct PaginatedDataGridView: View {
    let columns: [String]
    let columnTypes: [String]
    let rows: [[String?]]
    let page: Int
    let pageSize: Int
    let totalCount: Int
    let executionTime: TimeInterval
    let error: String?
    let isLoading: Bool
    let sortColumn: String?
    let sortAscending: Bool
    let onPageChange: (Int, Int) -> Void
    let onSortChange: (String?, Bool) -> Void
    let isEditable: Bool

    @Binding var selectedRow: Int?

    @Binding var stagedEdits: [String: String]
    @Binding var stagedNewRows: [StagedNewRow]
    @Binding var stagedDeletions: Set<Int>
    let onApplyChanges: () -> Void
    let onDiscardChanges: () -> Void

    @State private var hoveredCol: Int?
    @State private var columnWidths: [String: CGFloat] = [:]
    @State private var availableWidth: CGFloat = 800

    @State private var editingRow: Int?
    @State private var editingCol: Int?
    @State private var editBuffer: String = ""

    @State private var showDeleteConfirm = false
    @State private var confirmDeleteRow: Int?

    private let minColumnWidth: CGFloat = 60
    private let pageSizes = [100, 250, 500, 1000]

    private var pageCount: Int {
        max(1, Int(ceil(Double(max(totalCount, rows.count)) / Double(pageSize))))
    }

    private var startRow: Int {
        page * pageSize + 1
    }

    private var endRow: Int {
        min((page + 1) * pageSize, max(totalCount, rows.count))
    }

    private var displayTotal: Int {
        totalCount > 0 ? totalCount : rows.count
    }

    private var totalChanges: Int {
        stagedEdits.count + stagedNewRows.count + stagedDeletions.count
    }

    private var combination: (values: [[String?]], metas: [RowMeta]) {
        var values = rows
        var metas: [RowMeta] = rows.indices.map { RowMeta(isNew: false, sourceIndex: $0) }

        let sorted = stagedNewRows.enumerated().sorted { a, b in
            a.element.insertAfter < b.element.insertAfter
                || (a.element.insertAfter == b.element.insertAfter && a.offset < b.offset)
        }

        var offset = 0
        for (newIdx, newRow) in sorted {
            let pos = newRow.insertAfter == Int.max
                ? values.count
                : min(newRow.insertAfter + 1 + offset, values.count)
            values.insert(newRow.values, at: pos)
            metas.insert(RowMeta(isNew: true, sourceIndex: newIdx), at: pos)
            offset += 1
        }

        return (values, metas)
    }

    private var allRows: [[String?]] { combination.values }

    private var rowMetas: [RowMeta] { combination.metas }

    private func isNewRow(_ idx: Int) -> Bool {
        guard idx < rowMetas.count else { return false }
        return rowMetas[idx].isNew
    }

    private func isDeleteRow(_ idx: Int) -> Bool {
        guard idx < rowMetas.count, !rowMetas[idx].isNew else { return false }
        return stagedDeletions.contains(rowMetas[idx].sourceIndex)
    }

    private func displayValue(row: Int, col: Int) -> String? {
        guard row < rowMetas.count else { return nil }
        let meta = rowMetas[row]
        if meta.isNew {
            guard meta.sourceIndex < stagedNewRows.count, col < columns.count else { return nil }
            return stagedNewRows[meta.sourceIndex].values[col]
        }
        let key = "\(meta.sourceIndex):\(col)"
        if let edited = stagedEdits[key] {
            return edited
        }
        guard meta.sourceIndex < rows.count, col < rows[meta.sourceIndex].count else { return nil }
        return rows[meta.sourceIndex][col]
    }

    var body: some View {
        VStack(spacing: 0) {
            if let error = error {
                errorBanner(error)
            }

            if columns.isEmpty && error == nil {
                emptyState
            } else if !columns.isEmpty {
                gridContent
            }

            if displayTotal > 0 || !rows.isEmpty {
                paginationBar
            }

            if isEditable {
                changesBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Delete Row", isPresented: $showDeleteConfirm, presenting: confirmDeleteRow) { row in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                stagedDeletions.insert(row)
            }
        } message: { row in
            Text("Delete row \(startRow + row)? This will be applied when you save.")
        }
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12))
                .foregroundColor(.accentRed)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.accentRed)
                .lineLimit(3)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentRed.opacity(0.1))
        .overlay(Rectangle().frame(height: 1).foregroundColor(.accentRed.opacity(0.3)), alignment: .bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            if isLoading {
                ProgressView().scaleEffect(0.8).frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No results").font(.system(size: 12)).foregroundColor(.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Grid

    private var gridContent: some View {
        GeometryReader { proxy in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    Section {
                        rowsView
                    } header: {
                        headerView
                    }
                }
                .frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .topLeading)
            }
            .onAppear { availableWidth = proxy.size.width }
            .onChange(of: proxy.size.width) { availableWidth = $0 }
        }
        .background(Color.bgPrimary)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if isEditable {
                    Color.clear
                        .frame(width: 28, height: 28)
                        .overlay(
                            Rectangle().fill(Color.borderDefault).frame(width: 1),
                            alignment: .trailing
                        )
                }
                ForEach(Array(columns.enumerated()), id: \.offset) { idx, col in
                    headerCell(column: col, type: idx < columnTypes.count ? columnTypes[idx] : "", index: idx)
                }
            }
            Divider().background(Color.borderDefault)
        }
        .background(Color.bgSecondary)
    }

    private func headerCell(column: String, type: String, index: Int) -> some View {
        let width = columnWidth(for: column)
        return HStack(spacing: 3) {
            Image(systemName: typeIcon(for: type))
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
            Text(column)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .layoutPriority(1)
            Text(type)
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
                .lineLimit(1)
            if sortColumn == column {
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9))
                    .foregroundColor(.accentBlue)
            }
            Spacer(minLength: 0)
        }
        .frame(width: width - 16, height: 28, alignment: .leading)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture { toggleSort(column: column) }
        .overlay(
            Rectangle()
                .fill(Color.borderDefault)
                .frame(width: 1)
                .overlay(
                    Color.clear
                        .frame(width: 6)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                            let newWidth = max(minColumnWidth, width + value.translation.width)
                            columnWidths[column] = newWidth
                        })
                        .onHover { inside in
                            if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                        }
                ),
            alignment: .trailing
        )
    }

    private func typeIcon(for type: String) -> String {
        let l = type.lowercased()
        if l.contains("int") || l.contains("serial") || l.contains("numeric") || l.contains("decimal") || l.contains("float") || l.contains("double") || l.contains("real") || l.contains("money") { return "number" }
        if l.contains("char") || l.contains("text") || l.contains("varchar") || l.contains("name") || l.contains("json") || l.contains("xml") || l.contains("uuid") { return "textformat" }
        if l.contains("bool") { return "switch.2" }
        if l.contains("date") || l.contains("time") || l.contains("timestamp") || l.contains("interval") { return "calendar" }
        if l.contains("bytea") || l.contains("blob") || l.contains("binary") { return "doc" }
        if l.contains("point") || l.contains("line") || l.contains("polygon") || l.contains("circle") || l.contains("geometry") || l.contains("geography") || l.contains("path") || l.contains("box") { return "triangle" }
        if l.contains("inet") || l.contains("cidr") || l.contains("macaddr") { return "network" }
        if l.contains("array") || l.contains("[]") { return "list.bullet" }
        return "questionmark.diamond"
    }

    private func toggleSort(column: String) {
        let newAsc: Bool
        if sortColumn == column { newAsc = !sortAscending } else { newAsc = true }
        onSortChange(column, newAsc)
    }

    // MARK: - Rows

    private var rowsView: some View {
        let total = allRows.count
        return VStack(spacing: 0) {
            ForEach(0..<total, id: \.self) { rowIdx in
                rowView(rowIdx: rowIdx)
            }
            if isEditable {
                addRowButton
            }
        }
    }

    private var addRowButton: some View {
        Button(action: {
            var values: [String?] = Array(repeating: nil, count: columns.count)
            for i in 0..<min(columns.count, columnTypes.count) {
                let colName = columns[i].lowercased()
                let colType = columnTypes[i].lowercased()
                if isSerialType(colType) || isUUIDType(colType) || isIdColumn(colName) {
                    values[i] = "[auto]"
                } else if isDateType(colType) {
                    values[i] = formatDateNow(for: colType)
                }
            }
            stagedNewRows.append(StagedNewRow(insertAfter: Int.max, values: values))
        }) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill").font(.system(size: 11))
                Text("Add Row").font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.accentGreen)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color.accentGreen.opacity(0.04))
            .overlay(Rectangle().frame(height: 1).foregroundColor(.accentGreen.opacity(0.3)), alignment: .top)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Single Row

    private func rowView(rowIdx: Int) -> some View {
        let deleted = isDeleteRow(rowIdx)
        let newRow = isNewRow(rowIdx)
        let isSelected = selectedRow == rowIdx

        var bgColor = Color.clear
        if deleted {
            bgColor = Color.accentRed.opacity(0.12)
        } else if newRow {
            bgColor = Color.accentGreen.opacity(0.06)
        } else if isSelected {
            bgColor = Color.accentBlue.opacity(0.12)
        }

        return HStack(spacing: 0) {
            // Delete indicator
            if isEditable {
                deleteCell(rowIdx: rowIdx, deleted: deleted)
            }

            // Data cells
            ForEach(0..<columns.count, id: \.self) { colIdx in
                dataCell(rowIdx: rowIdx, colIdx: colIdx, deleted: deleted, newRow: newRow)
            }
        }
        .background(bgColor)
        .opacity(deleted ? 0.45 : 1)
        .overlay(
            deleted ? Rectangle().fill(Color.accentRed.opacity(0.35)).frame(height: 1) : nil,
            alignment: .center
        )
        .overlay(
            Rectangle().fill(Color.borderDefault.opacity(0.5)).frame(height: 1),
            alignment: .bottom
        )
        .onTapGesture {
            if editingRow == nil {
                selectedRow = (selectedRow == rowIdx) ? nil : rowIdx
            }
        }
        .contextMenu {
            if isEditable {
                Button(action: {
                    selectedRow = rowIdx
                    startEdit(rowIdx: rowIdx, colIdx: 0, value: displayValue(row: rowIdx, col: 0))
                }) {
                    Label("Edit", systemImage: "pencil")
                }

                Button(action: {
                    var values: [String?] = Array(repeating: nil, count: columns.count)
                    for i in 0..<min(columns.count, columnTypes.count) {
                        let colName = columns[i].lowercased()
                        let colType = columnTypes[i].lowercased()
                        if isSerialType(colType) || isUUIDType(colType) || isIdColumn(colName) {
                            values[i] = "[auto]"
                        } else if isDateType(colType) {
                            values[i] = formatDateNow(for: colType)
                        }
                    }
                    stagedNewRows.append(StagedNewRow(insertAfter: rowIdx, values: values))
                }) {
                    Label("Add Row", systemImage: "plus.square")
                }

                Divider()

                if newRow, rowIdx < rowMetas.count {
                    Button(role: .destructive, action: {
                        let newIdx = rowMetas[rowIdx].sourceIndex
                        guard newIdx < stagedNewRows.count else { return }
                        stagedNewRows.remove(at: newIdx)
                    }) {
                        Label("Discard Row", systemImage: "xmark.circle")
                    }
                } else if !newRow, rowIdx < rowMetas.count {
                    Button(role: .destructive, action: {
                        confirmDeleteRow = rowMetas[rowIdx].sourceIndex
                        showDeleteConfirm = true
                    }) {
                        Label("Delete Row", systemImage: "trash")
                    }
                }
            } else {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    let allVals = (0..<columns.count).compactMap { displayValue(row: rowIdx, col: $0) }.joined(separator: "\t")
                    NSPasteboard.general.setString(allVals, forType: .string)
                }) {
                    Label("Copy Row", systemImage: "doc.on.doc")
                }
            }
        }
    }

    // MARK: - Delete Cell

    private func deleteCell(rowIdx: Int, deleted: Bool) -> some View {
        let width: CGFloat = 28
        let isRowNew = rowIdx < rowMetas.count && rowMetas[rowIdx].isNew
        let originalIdx = rowIdx < rowMetas.count && !isRowNew ? rowMetas[rowIdx].sourceIndex : rowIdx
        return HStack(spacing: 0) {
            if deleted || isRowNew {
                Button(action: {
                    if isRowNew, rowIdx < rowMetas.count {
                        let newIdx = rowMetas[rowIdx].sourceIndex
                        guard newIdx < stagedNewRows.count else { return }
                        stagedNewRows.remove(at: newIdx)
                    } else if deleted {
                        stagedDeletions.remove(originalIdx)
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isRowNew ? .accentRed : .accentRed)
                        .frame(width: width, alignment: .center)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Discard new row")
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            } else {
                Button(action: {
                    confirmDeleteRow = originalIdx
                    showDeleteConfirm = true
                }) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                        .frame(width: width, alignment: .center)
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
        }
        .frame(width: width)
        .overlay(
            Rectangle().fill(Color.borderDefault.opacity(0.5)).frame(width: 1),
            alignment: .trailing
        )
    }

    // MARK: - Data Cell

    private func dataCell(rowIdx: Int, colIdx: Int, deleted: Bool, newRow: Bool) -> some View {
        let colName = colIdx < columns.count ? columns[colIdx] : "?"
        let w = columnWidth(for: colName)
        let originalIdx = rowIdx < rowMetas.count ? rowMetas[rowIdx].sourceIndex : rowIdx
        let key = "\(originalIdx):\(colIdx)"
        let val = displayValue(row: rowIdx, col: colIdx)
        let isNull = val == nil
        let isEditing = editingRow == rowIdx && editingCol == colIdx
        let hasEdit = !newRow && stagedEdits[key] != nil

        let textColor: Color = {
            if deleted { return .textTertiary }
            if isNull { return .textTertiary }
            if hasEdit { return .accentBlue }
            return .textPrimary
        }()

        let cellBg: Color = {
            if isEditing { return Color.accentBlue.opacity(0.08) }
            if hasEdit { return Color.accentBlue.opacity(0.05) }
            return .clear
        }()

        return ZStack(alignment: .leading) {
            if isEditing {
                TextField("", text: $editBuffer)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentBlue.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.accentBlue, lineWidth: 1))
                    .onSubmit { commitEdit(rowIdx: rowIdx, colIdx: colIdx) }
                    .onExitCommand { cancelEdit() }
            } else {
                HStack(spacing: 0) {
                    if hasEdit {
                        Image(systemName: "pencil")
                            .font(.system(size: 8))
                            .foregroundColor(.accentBlue)
                            .padding(.trailing, 3)
                    }
                    if newRow {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.accentGreen)
                            .padding(.trailing, 3)
                    }
                    if newRow, val == "[auto]" {
                        let placeholder = isUUIDType(columnTypes[safe: colIdx] ?? "") ? "uuid" : "auto-inc"
                        Text(placeholder)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.textTertiary.opacity(0.5))
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if isDateType(columnTypes[safe: colIdx] ?? "") && !isNull {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                                .foregroundColor(.textTertiary)
                            Text(val ?? "")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(textColor)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(isNull ? "NULL" : val ?? "")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(textColor)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(cellBg)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    if isEditable {
                        startEdit(rowIdx: rowIdx, colIdx: colIdx, value: val)
                    } else {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(val ?? "", forType: .string)
                    }
                }
            }
        }
        .frame(width: w, alignment: .leading)
        .overlay(
            Rectangle().fill(Color.borderDefault.opacity(0.5)).frame(width: 1),
            alignment: .trailing
        )
    }

    // MARK: - Edit Lifecycle

    private func startEdit(rowIdx: Int, colIdx: Int, value: String?) {
        editingRow = rowIdx
        editingCol = colIdx
        editBuffer = value ?? ""
    }

    private func commitEdit(rowIdx: Int, colIdx: Int) {
        defer {
            editingRow = nil
            editingCol = nil
        }

        guard rowIdx < rowMetas.count else { return }
        let meta = rowMetas[rowIdx]

        if meta.isNew {
            guard meta.sourceIndex < stagedNewRows.count, colIdx < columns.count else { return }
            stagedNewRows[meta.sourceIndex].values[colIdx] = editBuffer.isEmpty ? nil : editBuffer
            return
        }

        let key = "\(meta.sourceIndex):\(colIdx)"
        let oldRowIdx = meta.sourceIndex
        let wasNull = oldRowIdx < rows.count && colIdx < rows[oldRowIdx].count && rows[oldRowIdx][colIdx] == nil
        let oldVal = wasNull ? nil : (oldRowIdx < rows.count && colIdx < rows[oldRowIdx].count ? rows[oldRowIdx][colIdx] : nil)
        let newVal = editBuffer.isEmpty ? nil : editBuffer

        if newVal != oldVal {
            stagedEdits[key] = editBuffer
        } else {
            stagedEdits.removeValue(forKey: key)
        }
    }

    private func cancelEdit() {
        editingRow = nil
        editingCol = nil
    }

    // MARK: - Pagination Bar

    private var paginationBar: some View {
        HStack(spacing: 8) {
            Text("\(rows.count) row(s)")
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)

            if executionTime > 0 {
                Text(String(format: "in %.0fms", executionTime * 1000))
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
            }

            Spacer()

            if isLoading {
                ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
            }

            if displayTotal > 0 {
                Text("\(startRow)\u{2013}\(endRow) of \(displayTotal)")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                    .monospacedDigit()

                Button(action: { onPageChange(page - 1, pageSize) }) {
                    Image(systemName: "chevron.left").font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(page > 0 ? .textSecondary : .textTertiary)
                .disabled(page <= 0)

                Button(action: { onPageChange(page + 1, pageSize) }) {
                    Image(systemName: "chevron.right").font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(page < pageCount - 1 ? .textSecondary : .textTertiary)
                .disabled(page >= pageCount - 1)

                Picker("", selection: Binding(
                    get: { pageSize },
                    set: { onPageChange(0, $0) }
                )) {
                    ForEach(pageSizes, id: \.self) { s in Text("\(s)").tag(s) }
                }
                .pickerStyle(.menu)
                .menuStyle(BorderlessButtonMenuStyle())
                .frame(width: 60)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .top)
    }

    // MARK: - Changes Bar

    private var changesBar: some View {
        HStack(spacing: 8) {
            if totalChanges > 0 {
                HStack(spacing: 10) {
                    if stagedEdits.count > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "pencil").font(.system(size: 9)).foregroundColor(.accentBlue)
                            Text("\(stagedEdits.count)").font(.system(size: 10, weight: .medium)).foregroundColor(.accentBlue)
                        }
                    }
                    if stagedNewRows.count > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "plus.circle.fill").font(.system(size: 9)).foregroundColor(.accentGreen)
                            Text("\(stagedNewRows.count)").font(.system(size: 10, weight: .medium)).foregroundColor(.accentGreen)
                        }
                    }
                    if stagedDeletions.count > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 9)).foregroundColor(.accentRed)
                            Text("\(stagedDeletions.count)").font(.system(size: 10, weight: .medium)).foregroundColor(.accentRed)
                        }
                    }
                }

                Spacer()

                Button(action: onDiscardChanges) {
                    Text("Discard")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(Color.bgHover).cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: onApplyChanges) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 11))
                        Text("Apply (\(totalChanges))").font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 4)
                    .background(Color.accentGreen).cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .top)
    }

    // MARK: - Helpers

    private func columnWidth(for column: String) -> CGFloat {
        if let custom = columnWidths[column] { return custom }
        let count = max(1, columns.count)
        let usable = isEditable ? max(minColumnWidth, availableWidth - 28) : availableWidth
        return max(minColumnWidth, usable / CGFloat(count))
    }

    // MARK: - Column Detection

    private func isSerialType(_ type: String) -> Bool {
        type.contains("serial")
    }

    private func isIdColumn(_ name: String) -> Bool {
        name == "id" || name.hasSuffix("_id") || name == "codigo" || name == "cod"
    }

    private func isUUIDType(_ type: String) -> Bool {
        type.contains("uuid")
    }

    private func isDateType(_ type: String) -> Bool {
        type.contains("date") || type.contains("timestamp") || type.contains("timestamptz")
    }

    private func formatDateNow(for type: String) -> String {
        let now = Date()
        let lower = type.lowercased()
        if lower.contains("timestamp") || lower.contains("timestamptz") {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.string(from: now)
        }
        if lower.contains("date") {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: now)
        }
        if lower.contains("time") {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            return f.string(from: now)
        }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: now)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
