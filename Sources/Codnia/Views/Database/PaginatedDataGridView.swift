import SwiftUI

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

    @State private var hoveredRow: Int?
    @State private var selectedRow: Int?
    @State private var columnWidths: [String: CGFloat] = [:]
    @State private var availableWidth: CGFloat = 800
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

            if totalCount > 0 || !rows.isEmpty {
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
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    }

                    if displayTotal > 0 {
                        Text("\(startRow)\u{2013}\(endRow) of \(displayTotal)")
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
                            .monospacedDigit()

                        Button(action: {
                            print("[Pagination] Previous clicked: page=\(page) pageSize=\(pageSize)")
                            onPageChange(page - 1, pageSize)
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(page > 0 ? .textSecondary : .textTertiary)
                        .disabled(page <= 0)

                        Button(action: {
                            print("[Pagination] Next clicked: page=\(page) pageSize=\(pageSize) pageCount=\(pageCount)")
                            onPageChange(page + 1, pageSize)
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(page < pageCount - 1 ? .textSecondary : .textTertiary)
                        .disabled(page >= pageCount - 1)

                        Picker("", selection: Binding(
                            get: { pageSize },
                            set: { onPageChange(0, $0) }
                        )) {
                            ForEach(pageSizes, id: \.self) { size in
                                Text("\(size)").tag(size)
                            }
                        }
                        .pickerStyle(.menu)
                        .menuStyle(BorderlessButtonMenuStyle())
                        .frame(width: 60)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.bgSecondary)
                .overlay(
                    Rectangle().frame(height: 1).foregroundColor(.borderDefault),
                    alignment: .top
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error Banner

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
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.accentRed.opacity(0.3)),
            alignment: .bottom
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 4) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No results")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Grid Content

    private var gridContent: some View {
        GeometryReader { proxy in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    Section {
                        rowsContent
                    } header: {
                        headerRow
                    }
                }
                .frame(
                    minWidth: proxy.size.width,
                    minHeight: proxy.size.height,
                    alignment: .topLeading
                )
            }
            .textSelection(.enabled)
            .onAppear { availableWidth = proxy.size.width }
            .onChange(of: proxy.size.width) { availableWidth = $0 }
        }
        .background(Color.bgPrimary)
    }

    private var headerRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(columns.enumerated()), id: \.offset) { idx, col in
                    headerCell(column: col, type: idx < columnTypes.count ? columnTypes[idx] : "", index: idx)
                }
            }
            Divider()
                .background(Color.borderDefault)
        }
        .background(Color.bgSecondary)
    }

    private func headerCell(column: String, type: String, index: Int) -> some View {
        let width = columnWidth(for: column)
        let isLast = index == columns.count - 1
        let icon = typeIcon(for: type)

        return HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)

            Text(column)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .layoutPriority(1)

            if sortColumn == column {
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9))
                    .foregroundColor(.accentBlue)
            }

            Spacer(minLength: 2)

            Text(type)
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
                .lineLimit(1)

            if !isLast {
                Rectangle()
                    .fill(Color.borderDefault)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 4)
                    .overlay(
                        Color.clear
                            .frame(width: 6)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 1)
                                    .onChanged { value in
                                        let newWidth = max(minColumnWidth, width + value.translation.width)
                                        columnWidths[column] = newWidth
                                    }
                            )
                            .onHover { inside in
                                if inside {
                                    NSCursor.resizeLeftRight.push()
                                } else {
                                    NSCursor.pop()
                                }
                            },
                        alignment: .trailing
                    )
            }
        }
        .frame(width: width - 16, height: 28, alignment: .leading)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSort(column: column)
        }
    }

    private func typeIcon(for type: String) -> String {
        let lower = type.lowercased()
        if lower.contains("int") || lower.contains("serial") || lower.contains("numeric") || lower.contains("decimal") || lower.contains("float") || lower.contains("double") || lower.contains("real") || lower.contains("money") {
            return "number"
        }
        if lower.contains("char") || lower.contains("text") || lower.contains("varchar") || lower.contains("name") || lower.contains("json") || lower.contains("xml") || lower.contains("uuid") {
            return "textformat"
        }
        if lower.contains("bool") {
            return "switch.2"
        }
        if lower.contains("date") || lower.contains("time") || lower.contains("timestamp") || lower.contains("interval") {
            return "calendar"
        }
        if lower.contains("bytea") || lower.contains("blob") || lower.contains("binary") {
            return "doc"
        }
        if lower.contains("point") || lower.contains("line") || lower.contains("polygon") || lower.contains("circle") || lower.contains("geometry") || lower.contains("geography") || lower.contains("path") || lower.contains("box") {
            return "triangle"
        }
        if lower.contains("inet") || lower.contains("cidr") || lower.contains("macaddr") {
            return "network"
        }
        if lower.contains("array") || lower.contains("[]") {
            return "list.bullet"
        }
        return "questionmark.diamond"
    }

    private func toggleSort(column: String) {
        let newSortAsc: Bool
        if sortColumn == column {
            newSortAsc = !sortAscending
        } else {
            newSortAsc = true
        }
        onSortChange(column, newSortAsc)
    }

    // MARK: - Rows

    private var rowsContent: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIdx, cell in
                        let col = colIdx < columns.count ? columns[colIdx] : "?"
                        let w = columnWidth(for: col)

                        Text(cell ?? "NULL")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(cell == nil ? .textTertiary : .textPrimary)
                            .lineLimit(1)
                            .frame(width: w - 16, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(cell ?? "", forType: .string)
                            }
                    }
                }
                .background(
                    selectedRow == rowIdx
                        ? Color.accentBlue.opacity(0.15)
                        : (hoveredRow == rowIdx ? Color.bgHover : Color.clear)
                )
                .onHover { hovering in
                    hoveredRow = hovering ? rowIdx : nil
                }
                .onTapGesture {
                    selectedRow = (selectedRow == rowIdx) ? nil : rowIdx
                }
            }
        }
    }

    // MARK: - Helpers

    private func columnWidth(for column: String) -> CGFloat {
        if let custom = columnWidths[column] {
            return custom
        }
        let count = max(1, columns.count)
        let equal = availableWidth / CGFloat(count)
        return max(minColumnWidth, equal)
    }
}
