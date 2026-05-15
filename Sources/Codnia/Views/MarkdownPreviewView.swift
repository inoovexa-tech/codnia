import SwiftUI

struct MarkdownPreviewView: View {
    let content: String
    @State private var blocks: [Block] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    blockView(block)
                }
            }
            .textSelection(.enabled)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.bgPrimary)
        .onAppear { blocks = parseBlocks(content) }
        .onChange(of: content) { _ in blocks = parseBlocks(content) }
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .header(let level, let text):
            headerView(level: level, text: text)
        case .paragraph(let text):
            paragraphView(text)
        case .codeBlock(let code):
            codeBlockView(code)
        case .list(let items, let ordered):
            listView(items: items, ordered: ordered)
        case .blockquote(let text):
            blockquoteView(text)
        case .divider:
            dividerView()
        case .table(let headers, let alignments, let rows):
            tableView(headers: headers, alignments: alignments, rows: rows)
        }
    }

    private func headerView(level: Int, text: String) -> some View {
        let fontSize: CGFloat = [26, 22, 18, 16, 14, 13][min(max(level - 1, 0), 5)]
        return Text(inlineMarkdown(text, baseSize: fontSize))
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(.textPrimary)
            .padding(.top, level <= 2 ? 16 : 10)
    }

    @ViewBuilder
    private func paragraphView(_ text: String) -> some View {
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            Color.clear.frame(height: 8)
        } else {
            Text(inlineMarkdown(text, baseSize: 15))
        }
    }

    private func codeBlockView(_ code: String) -> some View {
        Text(AttributedString(code))
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.bgTertiary)
            .cornerRadius(6)
    }

    private func listView(items: [String], ordered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                HStack(alignment: .top, spacing: 6) {
                    let bullet = ordered ? "\(i + 1)." : "•"
                    Text(bullet)
                        .foregroundColor(.textSecondary)
                        .font(.system(size: 15))
                    Text(inlineMarkdown(item, baseSize: 15))
                }
            }
        }
    }

    private func blockquoteView(_ text: String) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.textTertiary.opacity(0.3))
                .frame(width: 3)
            Text(inlineMarkdown(text, baseSize: 14))
                .foregroundColor(.textSecondary)
                .padding(.leading, 12)
        }
    }

    private func dividerView() -> some View {
        Divider()
            .background(Color.borderLight.opacity(0.5))
    }

    private func tableView(headers: [String], alignments: [TextAlignment], rows: [[String]]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                        let alignment = index < alignments.count ? alignments[index] : .leading
                        Text(inlineMarkdown(header, baseSize: 13))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.textPrimary)
                            .frame(minWidth: 80, maxWidth: .infinity, alignment: alignment.frameAlignment)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                }
                .background(Color.bgTertiary)

                Divider()
                    .background(Color.borderLight)

                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                            let alignment = colIndex < alignments.count ? alignments[colIndex] : .leading
                            Text(inlineMarkdown(cell, baseSize: 13))
                                .frame(minWidth: 80, maxWidth: .infinity, alignment: alignment.frameAlignment)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                    }
                    .background(rowIndex % 2 == 1 ? Color.bgTertiary.opacity(0.4) : Color.clear)

                    if rowIndex < rows.count - 1 {
                        Divider()
                            .background(Color.borderLight.opacity(0.5))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.borderLight, lineWidth: 1)
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @MainActor
    private func inlineMarkdown(_ text: String, baseSize: CGFloat) -> AttributedString {
        guard let parsed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            var attr = AttributedString(text)
            attr.font = .systemFont(ofSize: baseSize)
            attr.foregroundColor = .textPrimary
            return attr
        }

        var result = parsed
        result.font = .systemFont(ofSize: baseSize)
        result.foregroundColor = .textPrimary

        for run in result.runs {
            if let inlineIntent = run.inlinePresentationIntent {
                if inlineIntent.contains(.code) {
                    result[run.range].font = .monospacedSystemFont(ofSize: baseSize - 1, weight: .regular)
                    result[run.range].foregroundColor = .accentOrange
                    result[run.range].backgroundColor = .bgTertiary
                }
            }
        }

        return result
    }
}

// MARK: - Parser

private enum Block {
    case header(level: Int, text: String)
    case paragraph(text: String)
    case codeBlock(code: String)
    case list(items: [String], ordered: Bool)
    case blockquote(text: String)
    case divider
    case table(headers: [String], alignments: [TextAlignment], rows: [[String]])
}

private func isOrderedListItem(_ line: String) -> Bool {
    let chars = Array(line)
    guard !chars.isEmpty, chars[0].isNumber else { return false }
    var i = 0
    while i < chars.count, chars[i].isNumber { i += 1 }
    return i < chars.count && chars[i] == "." && i + 1 < chars.count && chars[i + 1] == " "
}

private func isHeaderLine(_ line: String) -> Bool {
    var level = 0
    for ch in line {
        if ch == "#" { level += 1 }
        else { break }
    }
    return level > 0 && level <= 6 && line.count > level && line[line.index(line.startIndex, offsetBy: level)] == " "
}

private func isTableRow(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    return trimmed.hasPrefix("|") && trimmed.hasSuffix("|")
}

private func isTableSeparatorLine(_ line: String) -> Bool {
    let cells = parseTableRow(line)
    return cells.count > 0 && cells.allSatisfy { cell in
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return trimmed.allSatisfy { $0 == "-" || $0 == ":" }
    }
}

private func parseTableRow(_ line: String) -> [String] {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    var cells = trimmed.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
    if cells.first?.trimmingCharacters(in: .whitespaces).isEmpty ?? false {
        cells.removeFirst()
    }
    if cells.last?.trimmingCharacters(in: .whitespaces).isEmpty ?? false {
        cells.removeLast()
    }
    return cells.map { $0.trimmingCharacters(in: .whitespaces) }
}

private func parseTextAlignment(from cell: String) -> TextAlignment {
    let trimmed = cell.trimmingCharacters(in: .whitespaces)
    let left = trimmed.hasPrefix(":")
    let right = trimmed.hasSuffix(":")
    if left && right { return .center }
    if right { return .trailing }
    return .leading
}

private func parseBlocks(_ content: String) -> [Block] {
    var blocks: [Block] = []
    let lines = content.components(separatedBy: .newlines)
    var i = 0

    while i < lines.count {
        let line = lines[i]

        if line.hasPrefix("```") {
            var codeLines: [String] = []
            i += 1
            while i < lines.count && !lines[i].hasPrefix("```") {
                codeLines.append(lines[i])
                i += 1
            }
            blocks.append(.codeBlock(code: codeLines.joined(separator: "\n")))
            i += 1
            continue
        }

        if line.hasPrefix("> ") {
            var quoteLines: [String] = []
            while i < lines.count {
                let l = lines[i]
                if l.hasPrefix("> ") {
                    quoteLines.append(String(l.dropFirst(2)))
                    i += 1
                } else if l == ">" {
                    i += 1
                } else {
                    break
                }
            }
            blocks.append(.blockquote(text: quoteLines.joined(separator: "\n")))
            continue
        }

        if line.hasPrefix("---") || line.hasPrefix("***") || line.hasPrefix("___") {
            blocks.append(.divider)
            i += 1
            continue
        }

        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            var items: [String] = []
            while i < lines.count {
                let l = lines[i]
                if l.hasPrefix("- ") {
                    items.append(String(l.dropFirst(2)))
                    i += 1
                } else if l.hasPrefix("* ") {
                    items.append(String(l.dropFirst(2)))
                    i += 1
                } else if l.hasPrefix("+ ") {
                    items.append(String(l.dropFirst(2)))
                    i += 1
                } else {
                    break
                }
            }
            blocks.append(.list(items: items, ordered: false))
            continue
        }

        if isOrderedListItem(line) {
            var items: [String] = []
            while i < lines.count {
                let l = lines[i]
                if isOrderedListItem(l) {
                    if let dotIndex = l.firstIndex(of: ".") {
                        let text = String(l[l.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
                        items.append(text)
                    }
                    i += 1
                } else {
                    break
                }
            }
            blocks.append(.list(items: items, ordered: true))
            continue
        }

        if isHeaderLine(line) {
            var level = 0
            for ch in line {
                if ch == "#" { level += 1 }
                else { break }
            }
            let text = String(line.dropFirst(level + 1))
            blocks.append(.header(level: level, text: text))
            i += 1
            continue
        }

        if isTableRow(line) && i + 1 < lines.count && isTableSeparatorLine(lines[i + 1]) {
            let headers = parseTableRow(line)
            let alignments = parseTableRow(lines[i + 1]).map { parseTextAlignment(from: $0) }
            var rows: [[String]] = []
            i += 2
            while i < lines.count && isTableRow(lines[i]) {
                rows.append(parseTableRow(lines[i]))
                i += 1
            }
            blocks.append(.table(headers: headers, alignments: alignments, rows: rows))
            continue
        }

        var paraLines: [String] = []
        paraLines.append(line)
        i += 1
        while i < lines.count {
            let next = lines[i]
            if next.hasPrefix("```") || next.hasPrefix("> ") || next.hasPrefix("---") || next.hasPrefix("***") || next.hasPrefix("___") || next.hasPrefix("- ") || next.hasPrefix("* ") || next.hasPrefix("+ ") || isOrderedListItem(next) || isHeaderLine(next) || (isTableRow(next) && i + 1 < lines.count && isTableSeparatorLine(lines[i + 1])) {
                break
            }
            paraLines.append(next)
            i += 1
        }
        blocks.append(.paragraph(text: paraLines.joined(separator: "\n")))
    }

    return blocks
}

// MARK: - Helpers

private extension TextAlignment {
    var frameAlignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        @unknown default: return .leading
        }
    }
}
