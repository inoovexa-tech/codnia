import SwiftUI

struct DiffView: View {
    let diffLines: [DiffLine]
    let fileName: String
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var selectedLineId: UUID? = nil
    @State private var showMinimap: Bool = true

    // Detect language from file extension
    private var detectedLanguage: String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py": return "python"
        case "js": return "javascript"
        case "ts", "tsx": return "typescript"
        case "rs": return "rust"
        case "go": return "go"
        case "java", "kt": return "java"
        case "c", "cpp", "h", "cc": return "c"
        case "cs": return "csharp"
        case "rb": return "ruby"
        case "php": return "php"
        case "sh", "bash", "zsh": return "shell"
        case "yaml", "yml": return "yaml"
        case "sql": return "sql"
        default: return ""
        }
    }

    private var changeIndices: [Int] {
        diffLines.enumerated().compactMap { idx, line in
            line.isChanged ? idx : nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: true) {
                        ScrollViewReader { proxy in
                            LazyVStack(spacing: 0, pinnedViews: []) {
                                ForEach(Array(diffLines.enumerated()), id: \.1.id) { index, line in
                                    DiffRowView(
                                        line: line,
                                        isSelected: selectedLineId == line.id,
                                        language: detectedLanguage,
                                        onTap: {
                                            selectedLineId = line.id
                                        }
                                    )
                                    .id(line.id)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .onAppear {
                                scrollProxy = proxy
                            }
                        }
                    }
                    .frame(width: showMinimap ? geometry.size.width - 16 : geometry.size.width)

                    if showMinimap {
                        MinimapBar(
                            diffLines: diffLines,
                            onSelectLine: { id in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    scrollProxy?.scrollTo(id, anchor: .center)
                                    selectedLineId = id
                                }
                            }
                        )
                    }
                }
            }
        }
        .background(Color.bgPrimary)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(.accentGreen)

            Text(fileName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textPrimary)
                .lineLimit(1)

            Spacer()

            let stats = diffStats
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                    Text("\(stats.added)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                }

                HStack(spacing: 2) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.red)
                    Text("\(stats.removed)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                }
            }

            if !changeIndices.isEmpty {
                HStack(spacing: 4) {
                    Button {
                        jumpToPreviousChange()
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.textSecondary)
                    .help("Previous change")

                    Button {
                        jumpToNextChange()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.textSecondary)
                    .help("Next change")
                }
            }

            Button {
                showMinimap.toggle()
            } label: {
                Image(systemName: showMinimap ? "map.fill" : "map")
                    .font(.system(size: 11))
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
            .help("Toggle minimap")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }

    // MARK: - Minimap

    private var minimapBar: some View {
        GeometryReader { geo in
            let availableHeight = geo.size.height
            let rowCount = diffLines.count
            let rowHeight = max(1.5, availableHeight / CGFloat(max(rowCount, 1)))
            let totalHeight = CGFloat(rowCount) * rowHeight

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(diffLines) { line in
                        let color: Color = {
                            switch line.type {
                            case .added: return .green.opacity(0.7)
                            case .removed: return .red.opacity(0.7)
                            case .changed: return .yellow.opacity(0.7)
                            case .unchanged: return Color.bgSecondary.opacity(0.5)
                            }
                        }()

                        Rectangle()
                            .fill(color)
                            .frame(height: rowHeight)
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    scrollProxy?.scrollTo(line.id, anchor: .center)
                                    selectedLineId = line.id
                                }
                            }
                    }
                }
                .frame(width: 8, height: max(totalHeight, availableHeight))
            }
        }
        .frame(width: 12)
        .padding(.horizontal, 2)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(width: 1).foregroundColor(.borderDefault),
            alignment: .leading
        )
    }

    // MARK: - Navigation

    private func jumpToNextChange() {
        guard let currentId = selectedLineId,
              let currentIdx = diffLines.firstIndex(where: { $0.id == currentId }),
              let nextIdx = changeIndices.first(where: { $0 > currentIdx }) ?? changeIndices.first else {
            if let first = changeIndices.first {
                let lineId = diffLines[first].id
                withAnimation(.easeInOut(duration: 0.2)) {
                    scrollProxy?.scrollTo(lineId, anchor: .center)
                    selectedLineId = lineId
                }
            }
            return
        }

        let lineId = diffLines[nextIdx].id
        withAnimation(.easeInOut(duration: 0.2)) {
            scrollProxy?.scrollTo(lineId, anchor: .center)
            selectedLineId = lineId
        }
    }

    private func jumpToPreviousChange() {
        guard let currentId = selectedLineId,
              let currentIdx = diffLines.firstIndex(where: { $0.id == currentId }),
              let prevIdx = changeIndices.last(where: { $0 < currentIdx }) ?? changeIndices.last else {
            if let last = changeIndices.last {
                let lineId = diffLines[last].id
                withAnimation(.easeInOut(duration: 0.2)) {
                    scrollProxy?.scrollTo(lineId, anchor: .center)
                    selectedLineId = lineId
                }
            }
            return
        }

        let lineId = diffLines[prevIdx].id
        withAnimation(.easeInOut(duration: 0.2)) {
            scrollProxy?.scrollTo(lineId, anchor: .center)
            selectedLineId = lineId
        }
    }

    // MARK: - Stats

    private var diffStats: (added: Int, removed: Int) {
        var added = 0
        var removed = 0
        for line in diffLines {
            switch line.type {
            case .added: added += 1
            case .removed: removed += 1
            case .changed:
                added += 1
                removed += 1
            case .unchanged: break
            }
        }
        return (added, removed)
    }
}

// MARK: - Diff Row View

struct DiffRowView: View {
    let line: DiffLine
    let isSelected: Bool
    let language: String
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Left gutter — original line number
            Text(line.originalLineNumber.map { String($0) } ?? "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(gutterTextColor)
                .frame(width: 44, alignment: .trailing)
                .padding(.trailing, 6)
                .background(gutterBgColor)
                .overlay(
                    Rectangle()
                        .fill(leftGutterLeftBorder)
                        .frame(width: 3),
                    alignment: .leading
                )

            // Right gutter — modified line number
            Text(line.modifiedLineNumber.map { String($0) } ?? "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(gutterTextColor)
                .frame(width: 44, alignment: .trailing)
                .padding(.trailing, 6)
                .background(gutterBgColor)
                .overlay(
                    Rectangle()
                        .fill(rightGutterLeftBorder)
                        .frame(width: 3),
                    alignment: .leading
                )

            // Content area: show BOTH original (dimmed/strikethrough) AND modified side by side
            HStack(spacing: 0) {
                // Original side (dimmed for removed/changed)
                SyntaxHighlightedText(
                    text: line.originalLine ?? " ",
                    language: language,
                    opacity: line.originalLine != nil ? (line.type == .changed ? 0.45 : 1.0) : 0.0,
                    isStrikethrough: line.type == .removed
                )
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)

                // Divider
                Rectangle()
                    .fill(Color.borderDefault)
                    .frame(width: 1)
                    .padding(.vertical, 0)

                // Modified side
                SyntaxHighlightedText(
                    text: line.modifiedLine ?? " ",
                    language: language,
                    opacity: line.modifiedLine != nil ? 1.0 : 0.0
                )
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 20)
        .background(Color.bgPrimary)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(isSelected ? .accentBlue : Color.clear)
                .opacity(isSelected ? 1 : 0),
            alignment: .bottom
        )
        .overlay(
            Rectangle()
                .fill(isSelected ? Color.accentBlue.opacity(0.1) : Color.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { isHovered = $0 }
    }

    // MARK: - Colors (subtle, matching editor)

    private var gutterTextColor: Color {
        switch line.type {
        case .added, .removed, .changed:
            return .textSecondary
        case .unchanged:
            return .textTertiary
        }
    }

    private var gutterBgColor: Color {
        switch line.type {
        case .added:
            return Color.green.opacity(0.08)
        case .removed:
            return Color.red.opacity(0.08)
        case .changed:
            return Color.yellow.opacity(0.06)
        case .unchanged:
            return Color.bgPrimary
        }
    }

    private var leftGutterLeftBorder: Color {
        switch line.type {
        case .removed: return .red.opacity(0.5)
        case .changed: return .red.opacity(0.5)
        default: return .clear
        }
    }

    private var rightGutterLeftBorder: Color {
        switch line.type {
        case .added: return .green.opacity(0.5)
        case .changed: return .green.opacity(0.5)
        default: return .clear
        }
    }
}

// MARK: - Minimap Bar

struct MinimapBar: View {
    let diffLines: [DiffLine]
    let onSelectLine: (UUID) -> Void

    var body: some View {
        GeometryReader { geo in
            let availableHeight = geo.size.height
            let rowCount = diffLines.count
            let rowHeight = max(1.5, availableHeight / CGFloat(max(rowCount, 1)))
            let totalHeight = CGFloat(rowCount) * rowHeight

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(diffLines) { line in
                        let color: Color = {
                            switch line.type {
                            case .added: return .green.opacity(0.7)
                            case .removed: return .red.opacity(0.7)
                            case .changed: return .yellow.opacity(0.7)
                            case .unchanged: return Color.bgSecondary.opacity(0.5)
                            }
                        }()

                        Rectangle()
                            .fill(color)
                            .frame(height: rowHeight)
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                onSelectLine(line.id)
                            }
                    }
                }
                .frame(width: 8, height: max(totalHeight, availableHeight))
            }
        }
        .frame(width: 12)
        .padding(.horizontal, 2)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(width: 1).foregroundColor(.borderDefault),
            alignment: .leading
        )
    }
}
