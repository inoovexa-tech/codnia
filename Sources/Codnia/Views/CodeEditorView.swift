import SwiftUI

struct CodeEditorView: View {
    @Binding var content: String
    let language: String
    let onChange: () -> Void
    @EnvironmentObject var settings: SettingsService
    @EnvironmentObject var editorVM: EditorViewModel

    var body: some View {
        MacEditorView(
            text: $content,
            fontSize: settings.fontSize,
            showLineNumbers: settings.showLineNumbers,
            onChange: onChange,
            cursorPosition: { _, _ in },
            editorVM: editorVM
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
        .onAppear {
            // Ensure the editor becomes first responder when appearing
            DispatchQueue.main.async {
                if let window = NSApplication.shared.keyWindow,
                   let scrollView = window.contentView?.findSubview(ofType: NSScrollView.self),
                   let textView = scrollView.documentView as? NSTextView {
                    window.makeFirstResponder(textView)
                }
            }
        }
    }
}

extension NSView {
    func findSubview<T: NSView>(ofType type: T.Type) -> T? {
        if let view = self as? T {
            return view
        }
        for subview in subviews {
            if let found = subview.findSubview(ofType: type) {
                return found
            }
        }
        return nil
    }
}

struct MacEditorView: NSViewRepresentable {
    @Binding var text: String
    let fontSize: Double
    let showLineNumbers: Bool
    let onChange: () -> Void
    let cursorPosition: (Int, Int) -> Void
    var editorVM: EditorViewModel? = nil

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
        textView.font = NSFont(name: "SF Mono", size: CGFloat(fontSize))
            ?? NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        textView.textColor = NSColor(Color.textPrimary)
        textView.backgroundColor = NSColor(Color.bgPrimary)
        textView.insertionPointColor = NSColor(Color.accentBlue)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(Color.selectionBg),
            .foregroundColor: NSColor(Color.textPrimary)
        ]
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 4
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.smartInsertDeleteEnabled = false

        scrollView.documentView = textView

        if showLineNumbers {
            let ruler = LineNumberRulerView(scrollView: scrollView)
            scrollView.verticalRulerView = ruler
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
        }

        textView.string = text
        textView.applyHighlighting(language: detectLanguage(for: "Plain Text"))

        context.coordinator.textView = textView
        context.coordinator.editorVM = editorVM

        // Make the text view the first responder after a short delay
        DispatchQueue.main.async {
            if let window = textView.window {
                window.makeFirstResponder(textView)
            }
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? CodniaTextView else { return }

        // Only update text if it actually changed (avoid unnecessary updates that lose focus)
        if textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
            textView.applyHighlighting(language: detectLanguage(for: text))
            // Restore cursor position if valid
            if selected.location <= text.count && selected.location >= 0 {
                textView.setSelectedRange(selected)
            }
        }

        // Ensure text view is editable and selectable
        if !textView.isEditable {
            textView.isEditable = true
            textView.isSelectable = true
        }

        // Make first responder if needed (but avoid stealing focus from other views like find panel)
        if let window = textView.window,
           window.firstResponder != textView,
           let activeTabId = context.coordinator.parent.editorVM?.activeTabId,
           context.coordinator.parent.editorVM?.currentTab?.type == .file {
            window.makeFirstResponder(textView)
        }

        if let font = NSFont(name: "SF Mono", size: CGFloat(fontSize)) {
            textView.font = font
        }

        if let ruler = nsView.verticalRulerView as? LineNumberRulerView {
            ruler.setNeedsDisplay(ruler.bounds)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func detectLanguage(for textContent: String) -> CodeLanguage {
        // Default to plain text - actual detection happens in TabBarView
        // by setting the currentLanguage property on EditorViewModel
        return .plainText
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: MacEditorView
        weak var textView: CodniaTextView?
        weak var editorVM: EditorViewModel?

        init(_ parent: MacEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            parent.text = textView.string
            textView.applyHighlighting(language: parent.detectLanguage(for: textView.string))
            parent.onChange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange()
            let text = textView.string as NSString
            let line = text.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let lineNumber = text.substring(with: NSRange(location: 0, length: line.location))
                .components(separatedBy: "\n").count
            let col = selectedRange.location - line.location + 1
            parent.cursorPosition(lineNumber, col)
        }
    }
}

// MARK: - CodniaTextView

class CodniaTextView: NSTextView {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            self.isSelectable = true
            self.isEditable = true
        }
        return result
    }

    func applyHighlighting(language: CodeLanguage) {
        guard let textStorage = self.textStorage else { return }
        let currentText = self.string
        guard !currentText.isEmpty else { return }

        let fullRange = NSRange(location: 0, length: currentText.count)

        let baseFont = self.font
            ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: NSColor(Color.textPrimary)
        ]
        textStorage.addAttributes(baseAttrs, range: fullRange)

        let highlighter = SyntaxHighlighter()
        highlighter.highlight(text: currentText, in: textStorage, language: language)
    }
}

// MARK: - Line Number Ruler

class LineNumberRulerView: NSRulerView {
    weak var editorTextView: NSTextView? {
        return (scrollView?.documentView as? NSTextView)
    }

    init(scrollView: NSScrollView?) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.ruleThickness = 40
        self.clientView = scrollView?.documentView
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let textView = editorTextView else { return }

        NSColor.black.setFill() // Fallback
        dirtyRect.fill()

        // Draw separator
        let separator = NSBezierPath()
        separator.move(to: NSPoint(x: dirtyRect.maxX - 0.5, y: dirtyRect.minY))
        separator.line(to: NSPoint(x: dirtyRect.maxX - 0.5, y: dirtyRect.maxY))
        NSColor(Color.borderDefault).setStroke()
        separator.stroke()

        let layoutManager = textView.layoutManager!
        let textContainer = textView.textContainer!
        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let string = textView.string as NSString

        let startLine = string.lineRange(for: NSRange(location: charRange.location, length: 0))
        var lineNumber = string.substring(with: NSRange(location: 0, length: startLine.location))
            .components(separatedBy: "\n").count

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

enum CodeLanguage: String {
    case plainText = "Plain Text"
    case swift = "Swift"
    case rust = "Rust"
    case typescript = "TypeScript"
    case javascript = "JavaScript"
    case json = "JSON"
    case html = "HTML"
    case css = "CSS"
    case markdown = "Markdown"
    case python = "Python"
    case go = "Go"
    case yaml = "YAML"
    case shell = "Shell"

    var isSupported: Bool {
        return self != .plainText
    }
}

extension CodeLanguage {
    static func from(filename: String) -> CodeLanguage {
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        switch ext {
        case "swift": return .swift
        case "rs": return .rust
        case "ts", "tsx": return .typescript
        case "js", "jsx": return .javascript
        case "json": return .json
        case "html", "htm": return .html
        case "css", "scss": return .css
        case "md", "markdown": return .markdown
        case "py": return .python
        case "go": return .go
        case "yaml", "yml": return .yaml
        case "sh", "bash", "zsh": return .shell
        default: return .plainText
        }
    }

    static func from(languageName: String) -> CodeLanguage {
        switch languageName.lowercased() {
        case "swift": return .swift
        case "rust": return .rust
        case "typescript", "javascript": return languageName.lowercased() == "typescript" ? .typescript : .javascript
        case "json": return .json
        case "html": return .html
        case "css": return .css
        case "markdown", "md": return .markdown
        case "python": return .python
        case "go": return .go
        case "yaml", "yml": return .yaml
        case "shell", "sh": return .shell
        default: return .plainText
        }
    }
}

class SyntaxHighlighter {
    struct Token {
        let range: NSRange
        let attributes: [NSAttributedString.Key: Any]
    }

    func highlight(text: String, in textStorage: NSTextStorage, language: CodeLanguage) {
        guard language.isSupported else { return }
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
            tokens += highlightKeywords(in: nsText, keywords: swiftKeywords)
            tokens += highlightStrings(in: nsText, quote: "\"")
            tokens += highlightComments(in: nsText, singleLine: "//", multiLineStart: "/*", multiLineEnd: "*/")
            tokens += highlightNumbers(in: nsText)
            tokens += highlightTypes(in: nsText)

        case .rust:
            tokens += highlightKeywords(in: nsText, keywords: rustKeywords)
            tokens += highlightStrings(in: nsText, quote: "\"")
            tokens += highlightComments(in: nsText, singleLine: "//", multiLineStart: "/*", multiLineEnd: "*/")
            tokens += highlightNumbers(in: nsText)
            tokens += highlightLifetimes(in: nsText)

        case .typescript, .javascript:
            tokens += highlightKeywords(in: nsText, keywords: jsKeywords)
            tokens += highlightStrings(in: nsText, quote: "\"")
            tokens += highlightStrings(in: nsText, quote: "'")
            tokens += highlightTemplateLiterals(in: nsText)
            tokens += highlightComments(in: nsText, singleLine: "//", multiLineStart: "/*", multiLineEnd: "*/")
            tokens += highlightNumbers(in: nsText)

        case .json:
            tokens += highlightStrings(in: nsText, quote: "\"")
            tokens += highlightKeywords(in: nsText, keywords: ["true", "false", "null"])
            tokens += highlightNumbers(in: nsText)

        case .html:
            tokens += highlightTags(in: nsText)
            tokens += highlightStrings(in: nsText, quote: "\"")
            tokens += highlightComments(in: nsText, singleLine: nil, multiLineStart: "<!--", multiLineEnd: "-->")

        case .css:
            tokens += highlightCSSProperties(in: nsText)
            tokens += highlightNumbers(in: nsText)
            tokens += highlightStrings(in: nsText, quote: "\"")
            tokens += highlightComments(in: nsText, singleLine: "//", multiLineStart: "/*", multiLineEnd: "*/")

        case .markdown:
            tokens += highlightMarkdown(in: nsText)

        case .python:
            tokens += highlightKeywords(in: nsText, keywords: pythonKeywords)
            tokens += highlightStrings(in: nsText, quote: "\"")
            tokens += highlightStrings(in: nsText, quote: "'")
            tokens += highlightComments(in: nsText, singleLine: "#", multiLineStart: nil, multiLineEnd: nil)
            tokens += highlightNumbers(in: nsText)

        case .go:
            tokens += highlightKeywords(in: nsText, keywords: goKeywords)
            tokens += highlightStrings(in: nsText, quote: "\"")
            tokens += highlightComments(in: nsText, singleLine: "//", multiLineStart: "/*", multiLineEnd: "*/")
            tokens += highlightNumbers(in: nsText)

        case .yaml, .shell:
            tokens += highlightKeywords(in: nsText, keywords: ["true", "false", "yes", "no", "null"])
            tokens += highlightComments(in: nsText, singleLine: "#", multiLineStart: nil, multiLineEnd: nil)
            tokens += highlightStrings(in: nsText, quote: "\"")

        case .plainText:
            break
        }

        return tokens
    }

    // MARK: - Keyword Sets

    private var swiftKeywords: [String] {
        ["import", "class", "struct", "enum", "protocol", "extension", "func", "var", "let",
         "if", "else", "guard", "return", "for", "while", "switch", "case", "break", "continue",
         "throw", "try", "catch", "init", "deinit", "self", "super", "override", "lazy", "static",
         "mutating", "associatedtype", "typealias", "where", "in", "is", "as", "any", "some",
         "async", "await", "actor", "nonisolated", "Sendable"]
    }

    private var rustKeywords: [String] {
        ["use", "mod", "fn", "let", "mut", "const", "static", "struct", "enum", "trait", "impl",
         "pub", "self", "Self", "if", "else", "match", "return", "for", "while", "loop", "break",
         "continue", "unsafe", "async", "await", "move", "ref", "where", "as", "dyn", "type",
         "crate", "super"]
    }

    private var jsKeywords: [String] {
        ["import", "export", "from", "const", "let", "var", "function", "class", "interface",
         "type", "extends", "implements", "public", "private", "protected", "static", "async",
         "await", "return", "if", "else", "for", "while", "switch", "case", "break", "continue",
         "try", "catch", "throw", "new", "this", "super", "typeof", "instanceof", "in", "of", "as",
         "readonly", "declare", "namespace", "module", "enum"]
    }

    private var pythonKeywords: [String] {
        ["import", "from", "def", "class", "if", "elif", "else", "for", "while", "return",
         "try", "except", "finally", "with", "as", "lambda", "yield", "pass", "break", "continue",
         "raise", "assert", "global", "nonlocal", "del", "and", "or", "not", "in", "is",
         "True", "False", "None", "async", "await"]
    }

    private var goKeywords: [String] {
        ["package", "import", "func", "var", "const", "type", "struct", "interface", "map",
         "chan", "go", "defer", "if", "else", "for", "range", "return", "switch", "case",
         "default", "break", "continue", "fallthrough", "select", "make", "new", "append",
         "copy", "len", "cap", "nil", "true", "false", "iota"]
    }

    // MARK: - Highlighting Helpers

    private func highlightKeywords(in text: NSString, keywords: [String]) -> [Token] {
        let pattern = keywords.map { "\\b\($0)\\b" }.joined(separator: "|")
        return applyRegex(pattern: pattern, in: text, attributes: [.foregroundColor: NSColor(Color.accentBlue)])
    }

    private func highlightStrings(in text: NSString, quote: String) -> [Token] {
        let escapedQuote = NSRegularExpression.escapedPattern(for: quote)
        let pattern = "\(escapedQuote)(\\\\.|[^\\\\\(escapedQuote))*\(escapedQuote)"
        return applyRegex(pattern: pattern, in: text, attributes: [.foregroundColor: NSColor(Color.accentGreen)])
    }

    private func highlightTemplateLiterals(in text: NSString) -> [Token] {
        return applyRegex(pattern: "`(\\\\.|[^`])*`", in: text, attributes: [.foregroundColor: NSColor(Color.accentGreen)])
    }

    private func highlightNumbers(in text: NSString) -> [Token] {
        let pattern = "\\b(?:0x[0-9a-fA-F]+|0b[01]+|0o[0-7]+|\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)\\b"
        return applyRegex(pattern: pattern, in: text, attributes: [.foregroundColor: NSColor(Color.accentYellow)])
    }

    private func highlightComments(in text: NSString, singleLine: String?, multiLineStart: String?, multiLineEnd: String?) -> [Token] {
        var tokens: [Token] = []
        if let single = singleLine {
            let escaped = NSRegularExpression.escapedPattern(for: single)
            tokens += applyRegex(pattern: "\(escaped)[^\\n]*", in: text, attributes: [.foregroundColor: NSColor(Color.textTertiary)])
        }
        if let start = multiLineStart, let end = multiLineEnd {
            let escapedStart = NSRegularExpression.escapedPattern(for: start)
            let escapedEnd = NSRegularExpression.escapedPattern(for: end)
            tokens += applyRegex(pattern: "\(escapedStart)[\\s\\S]*?\(escapedEnd)", in: text, attributes: [.foregroundColor: NSColor(Color.textTertiary)])
        }
        return tokens
    }

    private func highlightTypes(in text: NSString) -> [Token] {
        let pattern = "(?<=\\bclass\\s+|\\bstruct\\s+|\\benum\\s+|\\bprotocol\\s+|\\btypealias\\s+|\\bextension\\s+)([A-Z][A-Za-z0-9_]*)"
        return applyRegex(pattern: pattern, in: text, attributes: [.foregroundColor: NSColor(Color.fileTs)])
    }

    private func highlightLifetimes(in text: NSString) -> [Token] {
        return applyRegex(pattern: "'[a-zA-Z_][a-zA-Z0-9_]*", in: text, attributes: [.foregroundColor: NSColor(Color.accentOrange)])
    }

    private func highlightTags(in text: NSString) -> [Token] {
        return applyRegex(pattern: "</?[a-zA-Z][a-zA-Z0-9-]*[^>]*>", in: text, attributes: [.foregroundColor: NSColor(Color.fileHtml)])
    }

    private func highlightCSSProperties(in text: NSString) -> [Token] {
        return applyRegex(pattern: "[a-z-]+(?=\\s*:)", in: text, attributes: [.foregroundColor: NSColor(Color.accentBlue)])
    }

    private func highlightMarkdown(in text: NSString) -> [Token] {
        var tokens: [Token] = []
        tokens += applyRegex(pattern: "^#{1,6}\\s.*$", in: text, options: .anchorsMatchLines,
                             attributes: [.foregroundColor: NSColor(Color.accentBlue), .font: NSFont.systemFont(ofSize: 14, weight: .bold)])
        tokens += applyRegex(pattern: "\\*\\*[^*]+\\*\\*|__[^_]+__", in: text,
                             attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .bold)])
        tokens += applyRegex(pattern: "`[^`]+`", in: text,
                             attributes: [.foregroundColor: NSColor(Color.accentGreen), .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)])
        return tokens
    }

    private func applyRegex(pattern: String, in text: NSString, options: NSRegularExpression.Options = [], attributes: [NSAttributedString.Key: Any]) -> [Token] {
        var tokens: [Token] = []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return tokens }
        let matches = regex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
        for match in matches {
            tokens.append(Token(range: match.range, attributes: attributes))
        }
        return tokens
    }
}

// MARK: - NSBezierPath Helper

private extension NSBezierPath {
    static func separator(in rect: NSRect) -> NSBezierPath? {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.maxX - 0.5, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX - 0.5, y: rect.maxY))
        return path
    }
}
