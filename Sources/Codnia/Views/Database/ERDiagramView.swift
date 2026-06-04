import SwiftUI
import UniformTypeIdentifiers

struct ERDiagramView: View {
    let configID: String
    let schema: String
    let databaseName: String

    @EnvironmentObject var databaseService: DatabaseConnectionService
    @State private var tables: [TableInfo] = []
    @State private var columns: [String: [ColumnInfo]] = [:]
    @State private var foreignKeys: [ForeignKeyInfo] = []
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var showExportMenu = false
    @State private var customPositions: [String: CGPoint] = [:]
    @State private var draggingCardId: String?
    @State private var cardDragOffset: CGSize = .zero
    @State private var searchText = ""
    @State private var viewportSize: CGSize = .zero

    private var filteredTableIds: Set<String> {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let q = searchText.lowercased()
        return Set(tables.filter { $0.name.lowercased().contains(q) }.map(\.id))
    }

    private let tableWidth: CGFloat = 180
    private let rowHeight: CGFloat = 22
    private let headerHeight: CGFloat = 28

    private var layoutStorageURL: URL? {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Codnia")
            .appendingPathComponent("ERLayouts")
        try? FileManager.default.createDirectory(at: dir!, withIntermediateDirectories: true)
        let safeName = "\(databaseName)_\(schema)".replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        return dir?.appendingPathComponent("\(safeName).json")
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

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
        .onDisappear {
            saveLayout()
        }
    }

    private var toolbar: some View {
        HStack {
            Text("ER Diagram: \(schema)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textPrimary)
            if !tables.isEmpty {
                SearchField(text: $searchText, placeholder: "Filter tables…")
                    .frame(width: 180)
                    .padding(.leading, 8)
            }
            Spacer()
            HStack(spacing: 4) {
                Button(action: zoomToFit) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 11))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Zoom to fit all tables")

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

                Button(action: resetLayout) {
                    Image(systemName: "clear")
                        .font(.system(size: 11))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Reset table positions to auto-layout")

                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)

                Button(action: { showExportMenu = true }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showExportMenu, arrowEdge: .bottom) {
                    VStack(spacing: 0) {
                        exportButton("Save as PNG…", icon: "doc.badge.arrow.down") {
                            showExportMenu = false
                            saveAsPNG()
                        }
                        Divider()
                        exportButton("Copy Image", icon: "doc.on.doc") {
                            showExportMenu = false
                            copyImage()
                        }
                    }
                    .frame(width: 180)
                    .padding(4)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }

    private func exportButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
    }

    // MARK: - Diagram Content

    private var diagramContent: some View {
        let activeSearch = !filteredTableIds.isEmpty
        let allPositions = layoutTables()
        let positions = activeSearch ? allPositions.filter { filteredTableIds.contains($0.table.id) } : allPositions
        let arrowPaths = layoutArrows(positions: allPositions)
        let contentBounds = boundingBox(positions: positions)
        let originOffset = CGSize(
            width: -contentBounds.minX + 80,
            height: -contentBounds.minY + 80
        )
        let cvWidth = max(600, contentBounds.width + 160)
        let cvHeight = max(400, contentBounds.height + 160)

        return GeometryReader { geo in
            let _ = { viewportSize = geo.size }()
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    Canvas { context, size in
                        for arrow in arrowPaths {
                            let from = CGPoint(x: arrow.from.x + originOffset.width, y: arrow.from.y + originOffset.height)
                            let to = CGPoint(x: arrow.to.x + originOffset.width, y: arrow.to.y + originOffset.height)

                            var path = Path()
                            path.move(to: from)
                            path.addLine(to: to)
                            context.stroke(path, with: .color(.accentBlue.opacity(0.5)), lineWidth: 1.5)

                            let angle = atan2(to.y - from.y, to.x - from.x)
                            let arrowLen: CGFloat = 10
                            let arrowAngle: CGFloat = .pi / 6
                            var arrowHead = Path()
                            arrowHead.move(to: to)
                            arrowHead.addLine(to: CGPoint(
                                x: to.x - arrowLen * cos(angle - arrowAngle),
                                y: to.y - arrowLen * sin(angle - arrowAngle)
                            ))
                            arrowHead.move(to: to)
                            arrowHead.addLine(to: CGPoint(
                                x: to.x - arrowLen * cos(angle + arrowAngle),
                                y: to.y - arrowLen * sin(angle + arrowAngle)
                            ))
                            context.stroke(arrowHead, with: .color(.accentBlue.opacity(0.5)), lineWidth: 1.5)

                            let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
                            let perp = CGPoint(x: -(to.y - from.y), y: to.x - from.x)
                            let perpLen = sqrt(perp.x * perp.x + perp.y * perp.y)
                            let offsetNorm = perpLen > 0 ? CGPoint(x: perp.x / perpLen * 12, y: perp.y / perpLen * 12) : CGPoint.zero

                            context.draw(Text(arrow.sourceLabel).font(.system(size: 9, weight: .bold)).foregroundColor(.accentBlue), at: CGPoint(x: from.x + offsetNorm.x, y: from.y + offsetNorm.y))
                            context.draw(Text(arrow.targetLabel).font(.system(size: 9, weight: .bold)).foregroundColor(.accentBlue), at: CGPoint(x: to.x + offsetNorm.x, y: to.y + offsetNorm.y))
                        }
                    }
                    .frame(width: cvWidth, height: cvHeight)

                    ForEach(positions.indices, id: \.self) { i in
                        let tr = positions[i]
                        let cardOffset: CGSize = draggingCardId == tr.table.id ? cardDragOffset : .zero
                        let isDimmed = activeSearch && !filteredTableIds.contains(tr.table.id)

                        TableCardView(
                            table: tr.table,
                            columns: columns[tr.table.id] ?? [],
                            foreignKeys: foreignKeys,
                            headerHeight: headerHeight,
                            rowHeight: rowHeight,
                            tableWidth: tableWidth
                        )
                        .shadow(color: draggingCardId == tr.table.id ? .black.opacity(0.15) : .clear, radius: 4)
                        .opacity(isDimmed ? 0.25 : 1)
                        .position(
                            x: tr.rect.midX + originOffset.width + cardOffset.width,
                            y: tr.rect.midY + originOffset.height + cardOffset.height
                        )
                        .gesture(
                            DragGesture(minimumDistance: 3)
                                .onChanged { value in
                                    draggingCardId = tr.table.id
                                    cardDragOffset = value.translation
                                }
                                .onEnded { value in
                                    let basePos = customPositions[tr.table.id] ?? tr.rect.origin
                                    customPositions[tr.table.id] = CGPoint(
                                        x: basePos.x + value.translation.width,
                                        y: basePos.y + value.translation.height
                                    )
                                    draggingCardId = nil
                                    cardDragOffset = .zero
                                    saveLayout()
                                }
                        )
                    }
                }
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
                            if draggingCardId == nil {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
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

    private func resetLayout() {
        customPositions = [:]
        saveLayout()
    }

    private func saveLayout() {
        guard let url = layoutStorageURL else { return }
        let dict = customPositions.mapValues { ["x": $0.x as CGFloat, "y": $0.y as CGFloat] }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) else { return }
        try? data.write(to: url)
    }

    private func loadLayout() {
        guard let url = layoutStorageURL,
              let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String: CGFloat]]
        else { return }
        customPositions = dict.compactMapValues { dict in
            guard let x = dict["x"], let y = dict["y"] else { return nil }
            return CGPoint(x: x, y: y)
        }
    }

    // MARK: - Export

    private func saveAsPNG() {
        guard let image = renderToImage() else { return }

        let panel = NSSavePanel()
        panel.title = "Export ER Diagram"
        panel.nameFieldStringValue = "ER Diagram - \(databaseName):\(schema).png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }

        guard let data = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
        try? pngData.write(to: url)
    }

    private func copyImage() {
        guard let image = renderToImage() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    private func renderToImage() -> NSImage? {
        let positions = layoutTables()
        let arrowPaths = layoutArrows(positions: positions)
        let bounds = boundingBox(positions: positions)
        let originOffset = CGSize(
            width: -bounds.minX + 80,
            height: -bounds.minY + 80
        )
        let w = max(600, bounds.width + 160)
        let h = max(400, bounds.height + 160)

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(w),
            pixelsHigh: Int(h),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        let savedContext = NSGraphicsContext.current
        guard let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.current = nsCtx

        let cgCtx = nsCtx.cgContext

        // Background
        cgCtx.setFillColor(NSColor.bgPrimary.cgColor)
        cgCtx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // Arrows
            cgCtx.setStrokeColor(NSColor.accentBlue.withAlphaComponent(0.5).cgColor)
            cgCtx.setLineWidth(1.5)
            for arrow in arrowPaths {
                let fx = arrow.from.x + originOffset.width
                let fy = arrow.from.y + originOffset.height
                let tx = arrow.to.x + originOffset.width
                let ty = arrow.to.y + originOffset.height
                let from = CGPoint(x: fx, y: h - fy)
                let to = CGPoint(x: tx, y: h - ty)

                cgCtx.beginPath()
                cgCtx.move(to: from)
                cgCtx.addLine(to: to)
                cgCtx.strokePath()

                let angle = atan2(to.y - from.y, to.x - from.x)
                let arrowLen: CGFloat = 10
                let arrowAngle: CGFloat = .pi / 6

                cgCtx.beginPath()
                cgCtx.move(to: to)
                cgCtx.addLine(to: CGPoint(
                    x: to.x - arrowLen * cos(angle - arrowAngle),
                    y: to.y - arrowLen * sin(angle - arrowAngle)
                ))
                cgCtx.move(to: to)
                cgCtx.addLine(to: CGPoint(
                    x: to.x - arrowLen * cos(angle + arrowAngle),
                    y: to.y - arrowLen * sin(angle + arrowAngle)
                ))
                cgCtx.strokePath()

                let perpX = -(to.y - from.y)
                let perpY = to.x - from.x
                let perpLen = sqrt(perpX * perpX + perpY * perpY)
                let offsetX = perpLen > 0 ? perpX / perpLen * 14 : CGFloat(0)
                let offsetY = perpLen > 0 ? perpY / perpLen * 14 : CGFloat(0)

                let srcLabel = arrow.sourceLabel as NSString
                let srcAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: NSColor.accentBlue]
                let srcSize = srcLabel.size(withAttributes: srcAttrs)
                srcLabel.draw(at: CGPoint(x: from.x + offsetX - srcSize.width / 2, y: from.y + offsetY - srcSize.height / 2), withAttributes: srcAttrs)

                let tgtLabel = arrow.targetLabel as NSString
                let tgtSize = tgtLabel.size(withAttributes: srcAttrs)
                tgtLabel.draw(at: CGPoint(x: to.x + offsetX - tgtSize.width / 2, y: to.y + offsetY - tgtSize.height / 2), withAttributes: srcAttrs)
            }

        // Tables
        for tableRect in positions {
            let rx = tableRect.rect.minX + originOffset.width
            let ry = h - (tableRect.rect.maxY + originOffset.height)
            let rect = CGRect(
                x: rx,
                y: ry,
                width: tableRect.rect.width,
                height: tableRect.rect.height
            )

            // Table body
            cgCtx.setFillColor(NSColor.bgSecondary.cgColor)
            cgCtx.fill(rect)
            cgCtx.setStrokeColor(NSColor.separatorColor.cgColor)
            cgCtx.setLineWidth(1)
            cgCtx.stroke(rect)

            // Header
            let headerY = h - (tableRect.rect.minY + originOffset.height + headerHeight)
            let headerRect = CGRect(
                x: rect.minX,
                y: headerY,
                width: rect.width,
                height: headerHeight
            )
            cgCtx.setFillColor(NSColor.accentBlue.withAlphaComponent(0.15).cgColor)
            cgCtx.fill(headerRect)

            // Header text
            let headerStr = tableRect.table.name as NSString
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.accentBlue
            ]
            let headerSize = headerStr.size(withAttributes: headerAttrs)
            headerStr.draw(
                at: CGPoint(x: rect.midX - headerSize.width / 2, y: headerRect.midY - headerSize.height / 2),
                withAttributes: headerAttrs
            )

            // Column divider
            let divY = h - (tableRect.rect.minY + originOffset.height + headerHeight + 0.25)
            cgCtx.setStrokeColor(NSColor.borderLight.cgColor)
            cgCtx.setLineWidth(0.5)
            cgCtx.beginPath()
            cgCtx.move(to: CGPoint(x: rect.minX, y: divY))
            cgCtx.addLine(to: CGPoint(x: rect.maxX, y: divY))
            cgCtx.strokePath()

            // Columns
            if let cols = columns[tableRect.table.id] {
                for (i, col) in cols.enumerated() {
                    let colY = h - (tableRect.rect.minY + originOffset.height + headerHeight + CGFloat(i + 1) * rowHeight)
                    let isFK = foreignKeys.contains { $0.table == tableRect.table.name && $0.column == col.name }
                    let isPK = col.name.lowercased() == "id" || col.name.hasSuffix("_id")

                    let prefix = isPK ? " ◈" : (isFK ? " ▸" : " ·")
                    let colStr = "\(prefix) \(col.name)  \(col.dataType)" as NSString
                    let colAttrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 10),
                        .foregroundColor: NSColor.textSecondary
                    ]
                    colStr.draw(
                        at: CGPoint(x: rect.minX + 8, y: colY + (rowHeight - colStr.size(withAttributes: colAttrs).height) / 2),
                        withAttributes: colAttrs
                    )
                }
            }

            // Row dividers
            if let cols = columns[tableRect.table.id] {
                for i in 0..<cols.count {
                    let rowDivY = h - (tableRect.rect.minY + originOffset.height + headerHeight + CGFloat(i + 1) * rowHeight - rowHeight)
                    cgCtx.setStrokeColor(NSColor.borderLight.withAlphaComponent(0.3).cgColor)
                    cgCtx.setLineWidth(0.3)
                    cgCtx.beginPath()
                    cgCtx.move(to: CGPoint(x: rect.minX + 4, y: rowDivY))
                    cgCtx.addLine(to: CGPoint(x: rect.maxX - 4, y: rowDivY))
                    cgCtx.strokePath()
                }
            }
        }

        NSGraphicsContext.current = savedContext

        let image = NSImage(size: NSSize(width: w, height: h))
        image.addRepresentation(rep)
        return image
    }

    // MARK: - Layout

    private struct TableRect {
        let table: TableInfo
        let rect: CGRect
        var path: Path { Path(rect) }
    }

    private struct ArrowPath {
        let from: CGPoint
        let to: CGPoint
        let sourceLabel: String
        let targetLabel: String
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

        loadLayout()
        isLoading = false
    }

    private func layoutTables() -> [TableRect] {
        let padding: CGFloat = 40
        let colSpacing: CGFloat = 120
        let rowSpacing: CGFloat = 140
        let columnsCount = max(1, Int(sqrt(Double(tables.count))))

        var result: [TableRect] = []
        for (i, table) in tables.enumerated() {
            let col = i % columnsCount
            let row = i / columnsCount
            let rowCount = columns[table.id]?.count ?? 1
            let height = headerHeight + CGFloat(rowCount) * rowHeight + 8

            let defaultX = padding + CGFloat(col) * (tableWidth + colSpacing)
            let defaultY = padding + CGFloat(row) * (height + rowSpacing)

            let origin = customPositions[table.id] ?? CGPoint(x: defaultX, y: defaultY)
            let rect = CGRect(origin: origin, size: CGSize(width: tableWidth, height: height))
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

            if !filteredTableIds.isEmpty,
               (!filteredTableIds.contains(fromTable.table.id) || !filteredTableIds.contains(toTable.table.id)) {
                continue
            }

            let fromPoint = CGPoint(x: fromTable.rect.maxX, y: fromTable.rect.midY)
            let toPoint = CGPoint(x: toTable.rect.minX, y: toTable.rect.midY)

            let srcCols = columns[fk.table] ?? []
            let isSrcPK = srcCols.contains { $0.name == fk.column && ($0.name.lowercased() == "id" || $0.name.hasSuffix("_id")) }
            let sourceLabel = isSrcPK ? "1" : "N"
            let targetLabel = "1"

            arrows.append(ArrowPath(from: fromPoint, to: toPoint, sourceLabel: sourceLabel, targetLabel: targetLabel))
        }
        return arrows
    }

    private func boundingBox(positions: [TableRect]) -> CGRect {
        guard !positions.isEmpty else { return .zero }
        let minX = positions.map { $0.rect.minX }.min()!
        let minY = positions.map { $0.rect.minY }.min()!
        let maxX = positions.map { $0.rect.maxX }.max()!
        let maxY = positions.map { $0.rect.maxY }.max()!
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func canvasWidth(positions: [TableRect]) -> CGFloat {
        let bounds = boundingBox(positions: positions)
        return max(600, bounds.width + 160)
    }

    private func canvasHeight(positions: [TableRect]) -> CGFloat {
        let bounds = boundingBox(positions: positions)
        return max(400, bounds.height + 160)
    }

    private func zoomToFit() {
        let allPositions = layoutTables()
        let bounds = boundingBox(positions: allPositions)
        guard bounds.width > 0 && bounds.height > 0 else { return }
        let padding: CGFloat = 80
        let targetW = viewportSize.width - padding
        let targetH = viewportSize.height - padding
        guard targetW > 0 && targetH > 0 else { return }
        let scaleX = targetW / bounds.width
        let scaleY = targetH / bounds.height
        scale = min(scaleX, scaleY, 3.0)
        offset = CGSize(
            width: -(bounds.midX * scale - viewportSize.width / 2),
            height: -(bounds.midY * scale - viewportSize.height / 2)
        )
        lastScale = scale
        lastOffset = offset
    }
}

// MARK: - Table Card View

struct TableCardView: View {
    let table: TableInfo
    let columns: [ColumnInfo]
    let foreignKeys: [ForeignKeyInfo]
    let headerHeight: CGFloat
    let rowHeight: CGFloat
    let tableWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Text(table.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.accentBlue)
                .frame(maxWidth: .infinity)
                .frame(height: headerHeight)
                .background(Color.accentBlue.opacity(0.15))

            Rectangle()
                .fill(Color.borderLight)
                .frame(height: 0.5)

            ForEach(Array(columns.enumerated()), id: \.element.name) { i, col in
                HStack(spacing: 4) {
                    let isFK = foreignKeys.contains { $0.table == table.name && $0.column == col.name }
                    let isPK = col.name.lowercased() == "id" || col.name.hasSuffix("_id")
                    let icon = isPK ? "key.fill" : (isFK ? "link" : "circle.fill")

                    Image(systemName: icon)
                        .font(.system(size: 8))
                        .foregroundColor(.textTertiary)
                        .frame(width: 10)

                    Text(col.name)
                        .font(.system(size: 10))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    Text(col.dataType)
                        .font(.system(size: 9))
                        .foregroundColor(.textTertiary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
                .frame(height: rowHeight)

                if i < columns.count - 1 {
                    Rectangle()
                        .fill(Color.borderLight.opacity(0.3))
                        .frame(height: 0.3)
                        .padding(.horizontal, 4)
                }
            }
        }
        .frame(width: tableWidth)
        .background(Color.bgSecondary)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
    }
}

struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.bezelStyle = .roundedBezel
        field.target = context.coordinator
        field.action = #selector(Coordinator.changed)
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }

        @objc func changed(_ sender: NSSearchField) {
            text = sender.stringValue
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            text = field.stringValue
        }
    }
}
