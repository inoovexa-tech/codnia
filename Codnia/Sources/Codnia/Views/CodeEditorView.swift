import SwiftUI

struct CodeEditorView: View {
    @Binding var content: String
    let language: String
    let onChange: () -> Void
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        MacEditorView(
            text: $content,
            fontSize: settings.fontSize,
            showLineNumbers: settings.showLineNumbers,
            onChange: onChange,
            cursorPosition: { [weak editorVM] line, col in
                editorVM?.updateCursorPosition(line: line, column: col)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
        .environmentObject(settings)
    }
}

struct MacEditorView: NSViewRepresentable {
    @Binding var text: String
    let fontSize: Double
    let showLineNumbers: Bool
    let onChange: () -> Void
    let cursorPosition: (Int, Int) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = NSColor(Color.bgPrimary)
        scrollView.drawsBackground = true

        let textView = CodniaTextView()
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.font = NSFont(name: "SF Mono", size: CGFloat(fontSize)) ?? NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        textView.textColor = NSColor(Color.textPrimary)
        textView.backgroundColor = NSColor(Color.bgPrimary)
        textView.insertionPointColor = NSColor(Color.accentBlue)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(Color.selectionBg),
            .foregroundColor: NSColor(Color.textPrimary)
        ]
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        // Remove default margins
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 4

        scrollView.documentView = textView

        // Line numbers ruler
        if showLineNumbers {
            let ruler = LineNumberRulerView(scrollView: scrollView)
            scrollView.verticalRulerView = ruler
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
        }

        // Set initial text
        textView.string = text

        // Apply syntax highlighting
        textView.applyHighlighting(language: detectLanguage())

        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? CodniaTextView else { return }

        if textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
            textView.applyHighlighting(language: detectLanguage())
            if selected.location <= text.count {
                textView.setSelectedRange(selected)
            }
        }

        if let font = NSFont(name: "SF Mono", size: CGFloat(fontSize)) {
            textView.font = font
        }

        // Update ruler
        if let ruler = nsView.verticalRulerView as? LineNumberRulerView {
            ruler.setNeedsDisplay(ruler.bounds)
        }

        context.coordinator.textView = textView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func detectLanguage() -> CodeLanguage {
        // Simplified detection based on extension or language string
        switch language.lowercased() {
        case "swift": return .swift
        case "rust": return .rust
        case "typescript", "tsx": return .typescript
        case "javascript", "jsx": return .javascript
        case "json": return .json
        case "html": return .html
        case "css", "scss": return .css
        case "markdown": return .markdown
        case "python": return .python
        case "go": return .go
        case "yaml", "yml": return .yaml
        case "shell", "sh": return .shell
        default: return .plainText
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: MacEditorView
        weak var textView: CodniaTextView?

        init(_ parent: MacEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            parent.text = textView.string
            textView.applyHighlighting(language: parent.detectLanguage())
            parent.onChange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange()
            let text = textView.string as NSString
            let line = text.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let lineNumber = text.substring(with: NSRange(location: 0, length: line.location)).components(separatedBy: "\n").count
            let col = selectedRange.location - line.location + 1
            parent.cursorPosition(lineNumber, col)
        }
    }
}

// MARK: - CodniaTextView

class CodniaTextView: NSTextView {
    override var isFlipped: Bool { true }

    func applyHighlighting(language: CodeLanguage) {
        guard let textStorage = self.textStorage else { return }
        let text = self.string
        guard !text.isEmpty else { return }

        let fullRange = NSRange(location: 0, length: text.count)

        // Reset to base attributes
        let baseFont = self.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: NSColor(Color.textPrimary)
        ]
        textStorage.addAttributes(baseAttrs, range: fullRange)

        // Apply language-specific highlighting
        let highlighter = SyntaxHighlighter()
        highlighter.highlight(text: text, in: textStorage, language: language)
    }
}

// MARK: - Line Number Ruler

class LineNumberRulerView: NSRulerView {
    weak var textView: NSTextView? {
        return (scrollView?.documentView as? NSTextView)
    }

    override init(scrollView: NSScrollView?) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.ruleThickness = 40
        self.clientView = scrollView?.documentView
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let textView = textView else { return }

        // Draw background
        NSColor(Color.bgPrimary).setFill()
        dirtyRect.fill()

        // Draw separator
        let separator = NSBezierPath()
        separator.move(to: NSPoint(x: dirtyRect.maxX - 0.5, y: dirtyRect.minY))
        separator.line(to: NSPoint(x: dirtyRect.maxX - 0.5, y: dirtyRect.maxY))
        NSColor(Color.borderDefault).setStroke()
        separator.stroke()

        // Get visible range
        let layoutManager = textView.layoutManager!
        let textContainer = textView.textContainer!
        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let string = textView.string as NSString

        // Find start line
        let startLine = string.lineRange(for: NSRange(location: charRange.location, length: 0))
        var lineNumber = (string.substring(with: NSRange(location: 0, length: startLine.location)).components(separatedBy: "\n")).count

        var currentLineCharIndex = startLine.location

        let paragraphAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor(Color.textTertiary)
        ]

        while currentLineCharIndex < NSMaxRange(charRange) {
            let lineRange = string.lineRange(for: NSRange(location: currentLineCharIndex, length: 0))
            let glyphRangeForLine = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            let lineRect = layoutManager.boundingRect(forGlyphRange: glyphRangeForLine, in: textContainer)
            let y = lineRect.origin.y + textView.textContainerInset.height - visibleRect.origin.y

            if y >= dirtyRect.minY && y <= dirtyRect.maxY {
                let lineString = "\(lineNumber)"
                let size = lineString.size(withAttributes: paragraphAttributes)
                let drawRect = NSRect(
                    x: dirtyRect.maxX - size.width - 8,
                    y: y - 1,
                    width: size.width,
                    height: size.height
                )
                lineString.draw(in: drawRect, withAttributes: paragraphAttributes)
            }

            lineNumber += 1
            currentLineCharIndex = NSMaxRange(lineRange)
        }
    }
}

// MARK: - Syntax Highlighter

enum CodeLanguage {
    case plainText, swift, rust, typescript, javascript, json, html, css, markdown, python, go, yaml, shell
}

class SyntaxHighlighter {
    func highlight(text: String, in textStorage: NSTextStorage, language: CodeLanguage) {
        let tokens = tokenize(text: text, language: language)
        for token in tokens {
            textStorage.addAttributes(token.attributes, range: token.range)
        }
    }

    private func tokenize(text: String, language: CodeLanguage) -> [Token] {
        var tokens: [Token] = []
        let nsText = text as NSString

        switch language {
        case .swift:
            tokens += highlightKeywords(in: nsText, keywords: ["import", "class", "struct", "enum", "protocol", "extension", "func", "var", "let", "if", "else", "guard", "return", "for", "while", "switch", "case", "break", "continue", "throw", "try", "catch", "init", "deinit", "self", "super", "override", "lazy", "static", "mutating", "associatedtype", "typealias", "where", "in", "is", "as", "any", "some", "async", "await", "actor", "nonisolated", "Sendable", "@main", "@Published", "@State", "@Binding", "@ObservedObject", "@Environment"], color: Color.accentBlue)
            tokens += highlightStrings(in: nsText)
            tokens += highlightComments(in: nsText, pattern: "//", multiline: "/*", multilineEnd: "*/")
            tokens += highlightNumbers(in: nsText)
            tokens += highlightTypes(in: nsText)

        case .rust:
            tokens += highlightKeywords(in: nsText, keywords: ["use", "mod", "fn", "let", "mut", "const", "static", "struct", "enum", "trait", "impl", "pub", "self", "Self", "if", "else", "match", "return", "for", "while", "loop", "break", "continue", "unsafe", "async", "await", "move", "ref", "where", "as", "dyn", "type", "crate", "super"], color: Color.accentBlue)
            tokens += highlightStrings(in: nsText)
            tokens += highlightComments(in: nsText, pattern: "//", multiline: "/*", multilineEnd: "*/")
            tokens += highlightNumbers(in: nsText)
            tokens += highlightLifetimes(in: nsText)

        case .typescript, .javascript:
            tokens += highlightKeywords(in: nsText, keywords: ["import", "export", "from", "const", "let", "var", "function", "class", "interface", "type", "extends", "implements", "public", "private", "protected", "static", "async", "await", "return", "if", "else", "for", "while", "switch", "case", "break", "continue", "try", "catch", "throw", "new", "this", "super", "typeof", "instanceof", "in", "of", "as", "readonly", "declare", "namespace", "module", "enum"], color: Color.accentBlue)
            tokens += highlightStrings(in: nsText, quote: "\"")
            tokens += highlightStrings(in: nsText, quote: "'")
            tokens += highlightTemplateLiterals(in: nsText)
            tokens += highlightComments(in: nsText, pattern: "//", multiline: "/*", multilineEnd: "*/")
            tokens += highlightNumbers(in: nsText)

        case .json:
            tokens += highlightStrings(in: nsText, quote: "\"")
            tokens += highlightKeywords(in: nsText, keywords: ["true", "false", "null"], color: Color.accentPurple)
            tokens += highlightNumbers(in: nsText)

        case .html:
            tokens += highlightTags(in: nsText)
            tokens += highlightStrings(in: nsText, quote: "\"")
            tokens += highlightComments(in: nsText, pattern: nil, multiline: "<!--", multilineEnd: "-->")

        case .css, .scss:
            tokens += highlightCSSProperties(in: nsText)
            tokens += highlightNumbers(in: nsText)
            tokens += highlightStrings(in: nsText, quote: "\"")
            tokens += highlightComments(in: nsText, pattern: "//", multiline: "/*", multilineEnd: "*/")

        case .markdown:
            tokens += highlightMarkdown(in: nsText)

        case .python:
            tokens += highlightKeywords(in: nsText, keywords: ["import", "from", "def", "class", "if", "elif", "else", "for", "while", "return", "try", "except", "finally", "with", "as", "lambda", "yield", "pass", "break", "continue", "raise", "assert", "global", "nonlocal", "del", "and", "or", "not", "in", "is", "True", "False", "None", "async", "await"], color: Color.accentBlue)
            tokens += highlightStrings(in: nsText)
            tokens += highlightComments(in: nsText, pattern: "#", multiline: nil, multilineEnd: nil)
            tokens += highlightNumbers(in: nsText)

        case .go:
            tokens += highlightKeywords(in: nsText, keywords: ["package", "import", "func", "var", "const", "type", "struct", "interface", "map", "chan", "go", "defer", "if", "else", "for", "range", "return", "switch", "case", "default", "break", "continue", "fallthrough", "select", "make", "new", "append", "copy", "len", "cap", "nil", "true", "false", "iota"], color: Color.accentBlue)
            tokens += highlightStrings(in: nsText)
            tokens += highlightComments(in: nsText, pattern: "//", multiline: "/*", multilineEnd: "*/")
            tokens += highlightNumbers(in: nsText)

        case .yaml, .shell:
            tokens += highlightKeywords(in: nsText, keywords: ["true", "false", "yes", "no", "null"], color: Color.accentPurple)
            tokens += highlightComments(in: nsText, pattern: "#", multiline: nil, multilineEnd: nil)
            tokens += highlightStrings(in: nsText)

        case .plainText:
            break
        }

        return tokens
    }

    // MARK: - Token Helpers

    private func highlightKeywords(in text: NSString, keywords: [String], color: Color) -> [Token] {
        var tokens: [Token] = []
        let pattern = keywords.map { "\\b\($0)\\b" }.joined(separator: "|")
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return tokens }
        let matches = regex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
        for match in matches {
            tokens.append(Token(range: match.range, attributes: [.foregroundColor: NSColor(color)]))
        }
        return tokens
    }

    private func highlightStrings(in text: NSString, quote: String = "\"") -> [Token] {
        var tokens: [Token] = []
        let pattern = "\(quote)(\\\\.|[^\\\(quote)])*\(quote)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return tokens }
        let matches = regex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
        for match in matches {
            tokens.append(Token(range: match.range, attributes: [.foregroundColor: NSColor(Color.accentGreen)]))
        }
        return tokens
    }

    private func highlightTemplateLiterals(in text: NSString) -> [Token] {
        var tokens: [Token] = []
        let pattern = "`(\\\\.|[^`])*`"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return tokens }
        let matches = regex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
        for match in matches {
            tokens.append(Token(range: match.range, attributes: [.foregroundColor: NSColor(Color.accentGreen)]))
        }
        return tokens
    }

    private func highlightComments(in text: NSString, pattern: String?, multiline: String?, multilineEnd: String?) -> [Token] {
        var tokens: [Token] = []
        if let pattern = pattern {
            let regexPattern = "\(NSRegularExpression.escapedPattern(for: pattern))[^\\n]*"
            guard let regex = try? NSRegularExpression(pattern: regexPattern) else { return tokens }
            let matches = regex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
            for match in matches {
                tokens.append(Token(range: match.range, attributes: [.foregroundColor: NSColor(Color.textTertiary)]))
            }
        }
        if let start = multiline, let end = multilineEnd {
            let escapedStart = NSRegularExpression.escapedPattern(for: start)
            let escapedEnd = NSRegularExpression.escapedPattern(for: end)
            let regexPattern = "\(escapedStart)[\\s\\S]*?\(escapedEnd)"
            guard let regex = try? NSRegularExpression(pattern: regexPattern, options: []) else { return tokens }
            let matches = regex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
            for match in matches {
                tokens.append(Token(range: match.range, attributes: [.foregroundColor: NSColor(Color.textTertiary)]))
            }
        }
        return tokens
    }

    private func highlightNumbers(in text: NSString) -> [Token] {
        var tokens: [Token] = []
        let pattern = "\\b(?:0x[0-9a-fA-F]+|0b[01]+|0o[0-7]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return tokens }
        let matches = regex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
        for match in matches {
            tokens.append(Token(range: match.range, attributes: [.foregroundColor: NSColor(Color.accentYellow)]))
        }
        return tokens
    }

    private func highlightTypes(in text: NSString) -> [Token] {
        var tokens: [Token] = []
        let pattern = "(?<=\\bclass\\s+|\\bstruct\\s+|\\benum\\s+|\\bprotocol\\s+|\\btypealias\\s+|\\bextension\\s+)([A-Z][A-Za-z0-9_]*)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return tokens }
        let matches = regex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
        for match in matches {
            tokens.append(Token(range: match.range(at: 1), attributes: [.foregroundColor: NSColor(Color.fileTs)]))
        }
        return tokens
    }

    private func highlightLifetimes(in text: NSString) -> [Token] {
        var tokens: [Token] = []
        let pattern = "'[a-zA-Z_][a-zA-Z0-9_]*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return tokens }
        let matches = regex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
        for match in matches {
            tokens.append(Token(range: match.range, attributes: [.foregroundColor: NSColor(Color.accentOrange)]))
        }
        return tokens
    }

    private func highlightTags(in text: NSString) -> [Token] {
        var tokens: [Token] = []
        let pattern = "</?[a-zA-Z][a-zA-Z0-9-]*[^>]*>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return tokens }
        let matches = regex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
        for match in matches {
            tokens.append(Token(range: match.range, attributes: [.foregroundColor: NSColor(Color.fileHtml)]))
        }
        return tokens
    }

    private func highlightCSSProperties(in text: NSString) -> [Token] {
        var tokens: [Token] = []
        let pattern = "[a-z-]+(?=\\s*:)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return tokens }
        let matches = regex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
        for match in matches {
            tokens.append(Token(range: match.range, attributes: [.foregroundColor: NSColor(Color.accentBlue)]))
        }
        return tokens
    }

    private func highlightMarkdown(in text: NSString) -> [Token] {
        var tokens: [Token] = []
        // Headers
        let headerPattern = "^#{1,6}\\s.*$"
        guard let headerRegex = try? NSRegularExpression(pattern: headerPattern, options: .anchorsMatchLines) else { return tokens }
        let headerMatches = headerRegex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
        for match in headerMatches {
            tokens.append(Token(range: match.range, attributes: [.foregroundColor: NSColor(Color.accentBlue), .font: NSFont.systemFont(ofSize: 14, weight: .bold)]))
        }

        // Bold
        let boldPattern = "\\*\\*[^*]+\\*\\*|__[^_]+__"
        guard let boldRegex = try? NSRegularExpression(pattern: boldPattern) else { return tokens }
        let boldMatches = boldRegex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
        for match in boldMatches {
            tokens.append(Token(range: match.range, attributes: [.foregroundColor: NSColor(Color.textPrimary), .font: NSFont.systemFont(ofSize: 13, weight: .bold)]))
        }

        // Italic
        let italicPattern = "\\*[^*]+\\*|_[^_]+_"
        guard let italicRegex = try? NSRegularExpression(pattern: italicPattern) else { return tokens }
        let italicMatches = italicRegex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
        for match in italicMatches {
            tokens.append(Token(range: match.range, attributes: [.foregroundColor: NSColor(Color.textPrimary), .font: NSFont.systemFont(ofSize: 13, weight: .regular)]))
        }

        // Code blocks
        let codePattern = "`[^`]+`"
        guard let codeRegex = try? NSRegularExpression(pattern: codePattern) else { return tokens }
        let codeMatches = codeRegex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
        for match in codeMatches {
            tokens.append(Token(range: match.range, attributes: [.foregroundColor: NSColor(Color.accentGreen), .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)]))
        }
        return tokens
    }
}

struct Token {
    let range: NSRange
    let attributes: [NSAttributedString.Key: Any]
}
