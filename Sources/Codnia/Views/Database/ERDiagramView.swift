import SwiftUI

struct ERDiagramView: View {
    let configID: String
    let schema: String

    @EnvironmentObject var databaseService: DatabaseConnectionService
    @State private var tables: [TableInfo] = []
    @State private var columns: [String: [ColumnInfo]] = [:]
    @State private var foreignKeys: [ForeignKeyInfo] = []
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero

    private let tableWidth: CGFloat = 180
    private let rowHeight: CGFloat = 22
    private let headerHeight: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ER Diagram: \(schema)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Button(action: { scale = max(0.3, scale - 0.1) }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                    Text("\(Int(scale * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                        .frame(width: 36)
                    Button(action: { scale = min(3.0, scale + 0.1) }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                    Button(action: resetZoom) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.bgSecondary)
            .overlay(
                Rectangle().frame(height: 1).foregroundColor(.borderDefault),
                alignment: .bottom
            )

            if isLoading {
                VStack(spacing: 8) {
                    Spacer()
                    ProgressView()
                    Text("Loading schema...")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tables.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.textTertiary)
                    Text("No tables found")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                diagramContent
            }
        }
        .background(Color.bgPrimary)
        .task {
            await loadSchema()
        }
    }

    private var diagramContent: some View {
        let positions = layoutTables()
        let arrowPaths = layoutArrows(positions: positions)

        return GeometryReader { geo in
            ScrollView([.horizontal, .vertical]) {
                Canvas { context, size in
                    for arrow in arrowPaths {
                        var path = Path()
                        path.move(to: arrow.from)
                        path.addLine(to: arrow.to)
                        context.stroke(path, with: .color(.accentBlue.opacity(0.5)), lineWidth: 1.5)

                        let angle = atan2(arrow.to.y - arrow.from.y, arrow.to.x - arrow.from.x)
                        let arrowLen: CGFloat = 10
                        let arrowAngle: CGFloat = .pi / 6
                        var arrowHead = Path()
                        arrowHead.move(to: arrow.to)
                        arrowHead.addLine(to: CGPoint(
                            x: arrow.to.x - arrowLen * cos(angle - arrowAngle),
                            y: arrow.to.y - arrowLen * sin(angle - arrowAngle)
                        ))
                        arrowHead.move(to: arrow.to)
                        arrowHead.addLine(to: CGPoint(
                            x: arrow.to.x - arrowLen * cos(angle + arrowAngle),
                            y: arrow.to.y - arrowLen * sin(angle + arrowAngle)
                        ))
                        context.stroke(arrowHead, with: .color(.accentBlue.opacity(0.5)), lineWidth: 1.5)
                    }

                    for tableRect in positions {
                        context.fill(tableRect.path, with: .color(Color.bgSecondary))
                        context.stroke(tableRect.path, with: .color(Color.borderDefault), lineWidth: 1)

                        let headerRect = CGRect(x: tableRect.rect.minX, y: tableRect.rect.minY, width: tableRect.rect.width, height: headerHeight)
                        let headerPath = Path(headerRect)
                        context.fill(headerPath, with: .color(Color.accentBlue.opacity(0.15)))

                        context.draw(Text(tableRect.table.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentBlue),
                            at: CGPoint(x: tableRect.rect.midX, y: tableRect.rect.minY + headerHeight / 2))

                        if let cols = columns[tableRect.table.id] {
                            for (i, col) in cols.enumerated() {
                                let y = tableRect.rect.minY + headerHeight + CGFloat(i) * rowHeight
                                let isFK = foreignKeys.contains { $0.table == tableRect.table.name && $0.column == col.name }
                                let isPK = col.name.lowercased() == "id" || col.name.hasSuffix("_id")

                                let icon = isPK ? "key.fill" : (isFK ? "link" : "circle.fill")

                                let colText = Text("  \(Image(systemName: icon)) \(col.name)")
                                    .font(.system(size: 10)) + Text("  \(col.dataType)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.textTertiary)

                                context.draw(colText, at: CGPoint(x: tableRect.rect.minX + 8, y: y + rowHeight / 2), anchor: .leading)
                            }
                        }

                        let columnDivider = Path(CGRect(x: tableRect.rect.minX, y: tableRect.rect.minY + headerHeight, width: tableRect.rect.width, height: 0.5))
                        context.stroke(columnDivider, with: .color(Color.borderLight), lineWidth: 0.5)
                    }
                }
                .frame(width: canvasWidth(positions: positions), height: canvasHeight(positions: positions))
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = max(0.3, min(3.0, lastScale * value))
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
            }
        }
    }

    private func resetZoom() {
        scale = 1.0
        offset = .zero
        lastScale = 1.0
        lastOffset = .zero
    }

    private struct TableRect {
        let table: TableInfo
        let rect: CGRect
        var path: Path { Path(rect) }
    }

    private struct ArrowPath {
        let from: CGPoint
        let to: CGPoint
    }

    private func loadSchema() async {
        isLoading = true
        let allTables = await databaseService.fetchTables(configID: configID, schema: schema)
        tables = allTables.filter { $0.tableType == .table }

        var cols: [String: [ColumnInfo]] = [:]
        for table in tables {
            let tableCols = await databaseService.fetchColumns(configID: configID, table: TableID(schema: schema, table: table.name))
            cols[table.id] = tableCols
        }
        columns = cols

        foreignKeys = await databaseService.fetchForeignKeys(configID: configID, schema: schema)
            .filter { fk in tables.contains(where: { $0.name == fk.table }) }

        isLoading = false
    }

    private func layoutTables() -> [TableRect] {
        let padding: CGFloat = 40
        let colSpacing: CGFloat = 60
        let rowSpacing: CGFloat = 80
        let columnsCount = max(1, Int(sqrt(Double(tables.count))))

        var result: [TableRect] = []
        for (i, table) in tables.enumerated() {
            let col = i % columnsCount
            let row = i / columnsCount
            let rowCount = columns[table.id]?.count ?? 1
            let height = headerHeight + CGFloat(rowCount) * rowHeight + 8

            let x = padding + CGFloat(col) * (tableWidth + colSpacing)
            let y = padding + CGFloat(row) * (height + rowSpacing)
            let rect = CGRect(x: x, y: y, width: tableWidth, height: height)
            result.append(TableRect(table: table, rect: rect))
        }
        return result
    }

    private func layoutArrows(positions: [TableRect]) -> [ArrowPath] {
        var arrows: [ArrowPath] = []
        for fk in foreignKeys {
            guard let fromTable = positions.first(where: { $0.table.name == fk.table }),
                  let toTable = positions.first(where: { $0.table.name == fk.foreignTable })
            else { continue }

            let fromPoint = CGPoint(x: fromTable.rect.maxX, y: fromTable.rect.midY)
            let toPoint = CGPoint(x: toTable.rect.minX, y: toTable.rect.midY)
            arrows.append(ArrowPath(from: fromPoint, to: toPoint))
        }
        return arrows
    }

    private func canvasWidth(positions: [TableRect]) -> CGFloat {
        guard let maxX = positions.map({ $0.rect.maxX }).max() else { return 600 }
        return maxX + 80
    }

    private func canvasHeight(positions: [TableRect]) -> CGFloat {
        guard let maxY = positions.map({ $0.rect.maxY }).max() else { return 400 }
        return maxY + 80
    }
}
