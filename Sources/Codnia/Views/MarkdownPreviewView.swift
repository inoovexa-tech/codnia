import SwiftUI

struct MarkdownPreviewView: View {
    let content: String
    @State private var renderedContent: AttributedString = AttributedString()

    var body: some View {
        ScrollView {
            Text(renderedContent)
                .textSelection(.enabled)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.bgPrimary)
        .onAppear { renderedContent = renderContent() }
        .onChange(of: content) { _ in renderedContent = renderContent() }
    }

    private func renderContent() -> AttributedString {
        var result = AttributedString()
        let blocks = parseBlocks(content)

        for (index, block) in blocks.enumerated() {
            if index > 0 {
                result += paddingBlock()
            }
            result += attributedBlock(block)
        }

        return result
    }

    private func attributedBlock(_ block: Block) -> AttributedString {
        switch block {
        case .header(let level, let text):
            let fontSize: CGFloat = [26, 22, 18, 16, 14, 13][min(max(level - 1, 0), 5)]
            let topPad: CGFloat = level <= 2 ? 16 : 10
            var attr = AttributedString(String(repeating: "\n", count: Int(topPad / 6)))
            attr.foregroundColor = .clear
            var textAttr = inlineMarkdown(text, baseSize: fontSize)
            textAttr.font = .systemFont(ofSize: fontSize, weight: .bold)
            textAttr.foregroundColor = .textPrimary
            attr += textAttr
            return attr

        case .paragraph(let text):
            if text.trimmingCharacters(in: .whitespaces).isEmpty {
                var attr = AttributedString("\n")
                attr.foregroundColor = .clear
                return attr
            }
            return inlineMarkdown(text, baseSize: 15)

        case .codeBlock(let code):
            var attr = AttributedString(code)
            attr.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            attr.foregroundColor = .textPrimary
            attr.backgroundColor = .bgTertiary
            return attr

        case .list(let items, let ordered):
            var result = AttributedString()
            for (i, item) in items.enumerated() {
                if i > 0 { result += AttributedString("\n") }
                let bullet = ordered ? "\(i + 1)." : "•"
                var bulletAttr = AttributedString(bullet + " ")
                bulletAttr.foregroundColor = .textSecondary
                bulletAttr.font = .systemFont(ofSize: 15)
                result += bulletAttr
                result += inlineMarkdown(item, baseSize: 15)
            }
            return result

        case .blockquote(let text):
            var bar = AttributedString("\u{00a0}\u{00a0}")
            bar.backgroundColor = Color.textTertiary.opacity(0.3)
            bar.foregroundColor = .clear
            var body = inlineMarkdown(text, baseSize: 14)
            body.foregroundColor = .textSecondary
            return bar + body

        case .divider:
            var attr = AttributedString(String(repeating: "\u{00a0}", count: 80))
            attr.foregroundColor = .clear
            attr.backgroundColor = Color.borderLight.opacity(0.5)
            return attr
        }
    }

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

    private func paddingBlock() -> AttributedString {
        var attr = AttributedString("\n")
        attr.foregroundColor = .clear
        return attr
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

        // Merge consecutive paragraph lines into one block
        var paraLines: [String] = []
        paraLines.append(line)
        i += 1
        while i < lines.count {
            let next = lines[i]
            if next.hasPrefix("```") || next.hasPrefix("> ") || next.hasPrefix("---") || next.hasPrefix("***") || next.hasPrefix("___") || next.hasPrefix("- ") || next.hasPrefix("* ") || next.hasPrefix("+ ") || isOrderedListItem(next) || isHeaderLine(next) {
                break
            }
            paraLines.append(next)
            i += 1
        }
        blocks.append(.paragraph(text: paraLines.joined(separator: "\n")))
    }

    return blocks
}
