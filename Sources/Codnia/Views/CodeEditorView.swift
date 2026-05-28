import SwiftUI
import AppKit

struct CodeEditorView: View {
    @Binding var content: String
    let language: String
    let onChange: () -> Void
    var searchResults: [NSRange] = []
    var currentSearchIndex: Int = 0
    let tabId: String
    let editorVM: EditorViewModel
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        ZStack {
            EditorNSTextView(
                text: $content,
                fontSize: settings.fontSize,
                showLineNumbers: settings.showLineNumbers,
                wordWrap: settings.wordWrap,
                tabSize: settings.tabSize,
                language: language,
                onChange: onChange,
                searchResults: searchResults,
                currentSearchIndex: currentSearchIndex,
                tabId: tabId,
                editorVM: editorVM
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}

// MARK: - Custom NSTextView for Keyboard Shortcuts

@MainActor
class CodniaTextView: NSTextView {
    weak var editorCoordinator: EditorNSTextView.Coordinator?
    private var optionClickPoint: NSPoint?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let key = event.charactersIgnoringModifiers else {
            return super.performKeyEquivalent(with: event)
        }

        switch (key, mods) {
        case ("d", [.command]):
            editorCoordinator?.handleDuplicateSelection()
            return true
        case ("d", [.command, .shift]):
            editorCoordinator?.handleDuplicateLine()
            return true
        case ("/", [.command]):
            editorCoordinator?.handleToggleComment()
            return true
        case ("l", [.command]):
            editorCoordinator?.handleSelectLine()
            return true
        case ("j", [.command]):
            editorCoordinator?.handleJoinLines()
            return true
        case ("g", [.command]):
            editorCoordinator?.handleGoToLine()
            return true
        case ("w", [.command, .shift]):
            editorCoordinator?.handleToggleWordWrap()
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            let point = convert(event.locationInWindow, from: nil)
            let index = characterIndexForInsertion(at: point)
            var ranges = selectedRanges.compactMap { ($0 as? NSValue)?.rangeValue }
            if !ranges.contains(where: { $0.location == index }) {
                ranges.append(NSRange(location: index, length: 0))
                setSelectedRanges(ranges.map { NSValue(range: $0) }, affinity: .downstream, stillSelecting: false)
            }
            return
        }
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if mods == [.command, .option] {
            let keyCode = event.keyCode
            if keyCode == 126 {
                editorCoordinator?.handleMoveLineUp()
                return
            } else if keyCode == 125 {
                editorCoordinator?.handleMoveLineDown()
                return
            }
        }

        let keyCode = event.keyCode
        if keyCode == 48 {
            if event.modifierFlags.contains(.shift) {
                if hasMultilineSelection() {
                    editorCoordinator?.handleUnindent()
                    return
                }
            } else {
                if hasMultilineSelection() {
                    editorCoordinator?.handleIndent()
                    return
                }
            }
        }

        super.keyDown(with: event)
    }

    private func hasMultilineSelection() -> Bool {
        let range = selectedRange()
        guard range.length > 0 else { return false }
        let nsString = string as NSString
        let startLine = nsString.lineRange(for: NSRange(location: range.location, length: 0))
        let endLine = nsString.lineRange(for: NSRange(location: range.location + range.length - 1, length: 0))
        return startLine.location != endLine.location
    }
}

// MARK: - NSViewRepresentable

struct EditorNSTextView: NSViewRepresentable {
    @Binding var text: String
    let fontSize: Double
    let showLineNumbers: Bool
    let wordWrap: Bool
    let tabSize: Int
    let language: String
    let onChange: () -> Void
    var searchResults: [NSRange] = []
    var currentSearchIndex: Int = 0
    let tabId: String
    let editorVM: EditorViewModel

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.bgPrimary

        let textView = CodniaTextView()
        textView.editorCoordinator = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        textView.textColor = nil
        textView.backgroundColor = NSColor.bgPrimary
        textView.insertionPointColor = NSColor.accentBlue
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectionBg,
            .foregroundColor: NSColor.white
        ]
        textView.isSelectable = true
        textView.isEditable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.allowsUndo = true

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = wordWrap
        }

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !wordWrap
        textView.autoresizingMask = [.width]
        textView.postsFrameChangedNotifications = true
        let ps = NSMutableParagraphStyle()
        ps.defaultTabInterval = CGFloat(tabSize * 8)
        textView.defaultParagraphStyle = ps
        textView.typingAttributes[.paragraphStyle] = ps

        scrollView.documentView = textView

        textView.textStorage?.setAttributedString(NSAttributedString(string: text))

        textView.delegate = context.coordinator

        context.coordinator.updateHighlighter(language: language)
        context.coordinator.applyHighlighting(textView)

        if showLineNumbers {
            let rulerView = LineNumberRulerView(textView: textView, scrollView: scrollView)
            rulerView.foldCoordinator = context.coordinator
            scrollView.verticalRulerView = rulerView
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
            context.coordinator.rulerView = rulerView
        }

        context.coordinator.configureScrollObserver(scrollView: scrollView)
        if editorVM.activeTextView !== textView { editorVM.activeTextView = textView }
        restoreSavedState(textView: textView, scrollView: scrollView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        context.coordinator.editorTabSize = tabSize

        if let textContainer = textView.textContainer, textContainer.widthTracksTextView != wordWrap {
            textContainer.widthTracksTextView = wordWrap
        }
        if textView.isHorizontallyResizable == wordWrap {
            textView.isHorizontallyResizable = !wordWrap
        }
        let ps = NSMutableParagraphStyle()
        ps.defaultTabInterval = CGFloat(tabSize * 8)
        if textView.defaultParagraphStyle?.defaultTabInterval != ps.defaultTabInterval {
            textView.defaultParagraphStyle = ps
            textView.typingAttributes[.paragraphStyle] = ps
        }

        let languageChanged = context.coordinator.currentLanguage != language
        context.coordinator.updateHighlighter(language: language)

        let textChanged = textView.string != text
        if textChanged {
            textView.textStorage?.setAttributedString(NSAttributedString(string: text))
            if let savedRange = editorVM.selectedRanges[tabId],
               savedRange.location <= text.count && savedRange.location >= 0 {
                textView.setSelectedRange(savedRange)
            }
            if let savedScrollY = editorVM.scrollPositions[tabId] {
                DispatchQueue.main.async {
                    nsView.contentView.bounds.origin = NSPoint(x: 0, y: savedScrollY)
                }
            }
        }

        context.coordinator.configureScrollObserver(scrollView: nsView)
        if editorVM.activeTextView !== textView { editorVM.activeTextView = textView }

        if languageChanged || textChanged {
            context.coordinator.applyHighlighting(textView)
        }
        context.coordinator.updateSearchResults(textView, results: searchResults, currentIndex: currentSearchIndex)

        if showLineNumbers && nsView.verticalRulerView == nil {
            let rulerView = LineNumberRulerView(textView: textView, scrollView: nsView)
            rulerView.foldCoordinator = context.coordinator
            nsView.verticalRulerView = rulerView
            nsView.hasVerticalRuler = true
            nsView.rulersVisible = true
            context.coordinator.rulerView = rulerView
        } else if !showLineNumbers && nsView.verticalRulerView != nil {
            nsView.verticalRulerView = nil
            nsView.hasVerticalRuler = false
            nsView.rulersVisible = false
            context.coordinator.rulerView = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, language: language, onChange: onChange, tabId: tabId, editorVM: editorVM)
    }

    private func restoreSavedState(textView: NSTextView, scrollView: NSScrollView) {
        if let savedRange = editorVM.selectedRanges[tabId],
           savedRange.location <= text.count && savedRange.location >= 0 {
            textView.setSelectedRange(savedRange)
        }
        if let savedScrollY = editorVM.scrollPositions[tabId] {
            DispatchQueue.main.async {
                scrollView.contentView.bounds.origin = NSPoint(x: 0, y: savedScrollY)
            }
        }
    }

    @MainActor
    class Coordinator: NSObject {
        @Binding var text: String
        let onChange: () -> Void
        let tabId: String
        let editorVM: EditorViewModel
        var highlighter: SyntaxHighlighter?
        var currentLanguage: String = ""
        var rulerView: LineNumberRulerView?
        private var isHighlighting = false
        private var scrollObserver: NSObjectProtocol?
        private var searchHighlightColor = NSColor(red: 255/255, green: 213/255, blue: 0/255, alpha: 0.3)
        private var currentHighlightColor = NSColor(red: 255/255, green: 140/255, blue: 0/255, alpha: 0.5)
        private let lineHighlightColor = NSColor.textSecondary.withAlphaComponent(0.06)
        private let bracketMatchColor = NSColor(red: 255/255, green: 200/255, blue: 0/255, alpha: 0.25)

        var editorTabSize: Int = 4
        var foldedContents: [String: String] = [:]
        private var currentLineRange: NSRange?
        private var bracketMatchRanges: [NSRange] = []
        private var storedSearchResults: [NSRange] = []
        private var storedSearchIndex: Int = 0
        private var selectionMatchRanges: [NSRange] = []
        private let selectionMatchHighlightColor = NSColor.textSecondary.withAlphaComponent(0.12)

        init(text: Binding<String>, language: String, onChange: @escaping () -> Void, tabId: String, editorVM: EditorViewModel) {
            self._text = text
            self.onChange = onChange
            self.tabId = tabId
            self.editorVM = editorVM
            self.currentLanguage = language
            self.highlighter = SyntaxHighlighter(language: language)
        }

        func updateHighlighter(language: String) {
            if currentLanguage != language {
                currentLanguage = language
                highlighter = SyntaxHighlighter(language: language)
            }
        }

        @MainActor func applyHighlighting(_ textView: NSTextView) {
            guard !isHighlighting, let highlighter = highlighter,
                  let textStorage = textView.textStorage else { return }
            isHighlighting = true
            highlighter.highlight(textStorage)
            textView.needsDisplay = true
            isHighlighting = false
        }

        func updateSearchResults(_ textView: NSTextView, results: [NSRange], currentIndex: Int) {
            storedSearchResults = results
            storedSearchIndex = currentIndex
            applyBackgroundHighlights(textView)
        }

        private func applyBackgroundHighlights(_ textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }

            let fullRange = NSRange(location: 0, length: textStorage.length)
            textStorage.beginEditing()

            textStorage.removeAttribute(.backgroundColor, range: fullRange)

            if let lineRange = currentLineRange, lineRange.location + lineRange.length <= textStorage.length {
                textStorage.addAttribute(.backgroundColor, value: lineHighlightColor, range: lineRange)
            }

            for range in bracketMatchRanges {
                if range.location + range.length <= textStorage.length {
                    textStorage.addAttribute(.backgroundColor, value: bracketMatchColor, range: range)
                }
            }

            for range in selectionMatchRanges {
                if range.location + range.length <= textStorage.length {
                    textStorage.addAttribute(.backgroundColor, value: selectionMatchHighlightColor, range: range)
                }
            }

            for (index, range) in storedSearchResults.enumerated() {
                if range.location + range.length <= textStorage.length {
                    let color = index == storedSearchIndex ? currentHighlightColor : searchHighlightColor
                    textStorage.addAttribute(.backgroundColor, value: color, range: range)
                }
            }

            textStorage.endEditing()
        }

        @MainActor func scrollToRange(_ textView: NSTextView, range: NSRange) {
            guard let layoutManager = textView.layoutManager else { return }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer ?? NSTextContainer())
            textView.scrollToVisible(rect)
        }

        func configureScrollObserver(scrollView: NSScrollView) {
            guard scrollObserver == nil else { return }
            scrollObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                guard let self = self else { return }
                let scrollY = scrollView.contentView.bounds.origin.y
                self.editorVM.scrollPositions[self.tabId] = scrollY
            }
        }

        deinit {
            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

// MARK: - Auto-Closing Brackets/Quotes

extension EditorNSTextView.Coordinator: NSTextViewDelegate {
    func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String?) -> Bool {
        guard let string = replacementString else { return true }

        if string == "\n" {
            let nsString = textView.string as NSString
            let lineRange = nsString.lineRange(for: NSRange(location: range.location, length: 0))
            let lineText = nsString.substring(with: lineRange)

            var indent = ""
            for ch in lineText {
                if ch == " " || ch == "\t" { indent.append(ch) }
                else { break }
            }

            let trimmed = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasSuffix("{") {
                indent += String(repeating: " ", count: editorTabSize)
            }

            let insertion = "\n" + indent
            textView.insertText(insertion, replacementRange: range)
            return false
        }

        guard string.count == 1 else { return true }

        let pairs: [Character: Character] = ["(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'", "`": "`"]
        guard let close = pairs[string.first!] else { return true }

        if range.length > 0 {
            let selected = (textView.string as NSString).substring(with: range)
            textView.insertText(string + selected + String(close), replacementRange: range)
            return false
        }

        let nsString = textView.string as NSString
        if range.location < nsString.length {
            let nextChar = nsString.substring(with: NSRange(location: range.location, length: 1))
            if nextChar == String(close) {
                textView.setSelectedRange(NSRange(location: range.location + 1, length: 0))
                return false
            }
        }

        textView.insertText(string + String(close), replacementRange: range)
        textView.setSelectedRange(NSRange(location: range.location + 1, length: 0))
        return false
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        text = textView.string
        applyHighlighting(textView)
        rulerView?.needsDisplay = true
        onChange()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        let newRange = textView.selectedRange()
        if editorVM.selectedRanges[tabId] == newRange { return }
        editorVM.selectedRanges[tabId] = newRange

        let nsString = textView.string as NSString
        let line = nsString.length == 0 ? 1 : nsString.substring(to: min(newRange.location, nsString.length)).components(separatedBy: "\n").count
        let column: Int = {
            let loc = newRange.location
            let lineStart = nsString.lineRange(for: NSRange(location: loc, length: 0))
            return loc - lineStart.location + 1
        }()
        let newPosition = "Ln \(line), Col \(column)"
        if editorVM.cursorPosition != newPosition {
            editorVM.cursorPosition = newPosition
            editorVM.cursorPositions[tabId] = newPosition
        }

        updateSelectionHighlights(textView)
    }

    private func updateSelectionHighlights(_ textView: NSTextView) {
        let nsString = textView.string as NSString
        let selectedRange = textView.selectedRange()
        let cursorPos = selectedRange.location

        if cursorPos <= nsString.length {
            currentLineRange = nsString.lineRange(for: NSRange(location: cursorPos, length: 0))
        } else {
            currentLineRange = nil
        }

        bracketMatchRanges = findMatchingBracket(textView, at: cursorPos)

        if selectedRange.length > 0 {
            let selectedText = nsString.substring(with: selectedRange)
            if selectedText.rangeOfCharacter(from: .newlines) == nil && !selectedText.trimmingCharacters(in: .whitespaces).isEmpty {
                selectionMatchRanges = findAllOccurrences(of: selectedText, in: textView.string)
            } else {
                selectionMatchRanges = []
            }
        } else {
            selectionMatchRanges = []
        }

        applyBackgroundHighlights(textView)
    }

    private func findAllOccurrences(of query: String, in text: String) -> [NSRange] {
        guard !query.isEmpty else { return [] }
        let nsString = text as NSString
        var ranges: [NSRange] = []
        var searchStart = 0
        while searchStart < nsString.length {
            let range = nsString.range(of: query, options: .caseInsensitive, range: NSRange(location: searchStart, length: nsString.length - searchStart))
            if range.location == NSNotFound { break }
            ranges.append(range)
            searchStart = range.location + range.length
        }
        return ranges
    }

    private func findMatchingBracket(_ textView: NSTextView, at cursorPos: Int) -> [NSRange] {
        let nsString = textView.string as NSString
        guard cursorPos > 0, cursorPos <= nsString.length else { return [] }

        let openBrackets: [Character: Character] = ["(": ")", "[": "]", "{": "}"]
        let closeBrackets: [Character: Character] = [")": "(", "]": "[", "}": "{"]

        let charBefore = nsString.substring(with: NSRange(location: cursorPos - 1, length: 1)).first!

        if let expectedClose = openBrackets[charBefore] {
            let cursorRange = NSRange(location: cursorPos - 1, length: 1)
            if let matchPos = findMatch(in: nsString, from: cursorPos - 1, open: charBefore, close: expectedClose, direction: 1) {
                let matchRange = NSRange(location: matchPos, length: 1)
                return [cursorRange, matchRange]
            }
            return [cursorRange]
        }

        if cursorPos < nsString.length {
            let charAt = nsString.substring(with: NSRange(location: cursorPos, length: 1)).first!
            if let expectedOpen = closeBrackets[charAt] {
                let cursorRange = NSRange(location: cursorPos, length: 1)
                if let matchPos = findMatch(in: nsString, from: cursorPos, open: expectedOpen, close: charAt, direction: -1) {
                    let matchRange = NSRange(location: matchPos, length: 1)
                    return [cursorRange, matchRange]
                }
                return [cursorRange]
            }
        }

        return []
    }

    private func findMatch(in nsString: NSString, from start: Int, open: Character, close: Character, direction: Int) -> Int? {
        var depth = 0
        var pos = start

        while pos >= 0 && pos < nsString.length {
            let char = nsString.character(at: pos)
            let unichar = Character(UnicodeScalar(char)!)
            if unichar == open {
                depth += 1
            } else if unichar == close {
                depth -= 1
                if depth == 0 {
                    return pos
                }
            }
            pos += direction
        }
        return nil
    }
}

// MARK: - Editor Actions

extension EditorNSTextView.Coordinator {
    func handleDuplicateSelection() {
        guard let textView = editorVM.activeTextView else { return }
        let range = textView.selectedRange()
        let nsString = textView.string as NSString

        if range.length > 0 {
            let selected = nsString.substring(with: range)
            textView.insertText(selected, replacementRange: NSRange(location: range.location, length: 0))
            textView.setSelectedRange(NSRange(location: range.location + range.length, length: range.length))
        } else {
            let lineRange = nsString.lineRange(for: range)
            let lineText = nsString.substring(with: lineRange)
            let insertPos = lineRange.location + lineRange.length
            textView.insertText(lineText, replacementRange: NSRange(location: insertPos, length: 0))
            textView.setSelectedRange(NSRange(location: insertPos, length: 0))
        }
    }

    func handleDuplicateLine() {
        guard let textView = editorVM.activeTextView else { return }
        let nsString = textView.string as NSString
        let cursorRange = textView.selectedRange()
        let lineRange = nsString.lineRange(for: NSRange(location: cursorRange.location, length: 0))
        let lineText = nsString.substring(with: lineRange)
        let insertPos = lineRange.location + lineRange.length
        textView.insertText(lineText, replacementRange: NSRange(location: insertPos, length: 0))
        textView.setSelectedRange(NSRange(location: insertPos, length: 0))
    }

    func handleToggleComment() {
        guard let textView = editorVM.activeTextView else { return }
        let nsString = textView.string as NSString
        let range = textView.selectedRange()
        let prefix = commentPrefix()

        if range.length > 0 {
            let startLine = nsString.lineRange(for: NSRange(location: range.location, length: 0))
            let endLine = nsString.lineRange(for: NSRange(location: range.location + range.length - 1, length: 0))
            var allLines: [String] = []
            var lineStart = startLine.location
            while lineStart <= endLine.location {
                let lineR = nsString.lineRange(for: NSRange(location: lineStart, length: 0))
                let lineText = nsString.substring(with: lineR)
                let trimmed = lineText.hasSuffix("\n") ? String(lineText.dropLast()) : lineText
                allLines.append(trimmed)
                lineStart = lineR.location + lineR.length
            }

            let allCommented = allLines.allSatisfy { $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) }
            let replacement: String
            if allCommented {
                replacement = allLines.map { line in
                    if let r = line.range(of: prefix) {
                        var result = line
                        result.removeSubrange(r)
                        return result
                    }
                    return line
                }.joined(separator: "\n") + "\n"
            } else {
                replacement = allLines.map { "\(prefix)\($0)" }.joined(separator: "\n") + "\n"
            }
            textView.insertText(replacement, replacementRange: NSUnionRange(startLine, endLine))
        } else {
            let cursorRange = textView.selectedRange()
            let lineRange = nsString.lineRange(for: NSRange(location: cursorRange.location, length: 0))
            let lineText = nsString.substring(with: lineRange)

            if lineText.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) {
                if let r = lineText.range(of: prefix) {
                    var result = lineText
                    result.removeSubrange(r)
                    textView.insertText(result, replacementRange: lineRange)
                    let newCursor = cursorRange.location - prefix.count
                    textView.setSelectedRange(NSRange(location: max(cursorRange.location - prefix.count, lineRange.location), length: 0))
                }
            } else {
                textView.insertText("\(prefix)\(lineText)", replacementRange: lineRange)
                let newCursor = cursorRange.location + prefix.count
                textView.setSelectedRange(NSRange(location: newCursor, length: 0))
            }
        }
    }

    private func commentPrefix() -> String {
        switch currentLanguage.lowercased() {
        case "swift", "typescript", "javascript", "rust", "go", "java", "kotlin",
             "c", "cpp", "c#", "csharp", "php", "css", "scss", "dart", "groovy":
            return "//"
        case "python", "ruby", "shell", "bash", "zsh", "yaml", "toml", "perl", "r":
            return "#"
        case "sql":
            return "-- "
        default:
            return "//"
        }
    }

    func handleIndent() {
        guard let textView = editorVM.activeTextView else { return }
        let indent = String(repeating: " ", count: editorTabSize)
        let nsString = textView.string as NSString
        let range = textView.selectedRange()
        let startLine = nsString.lineRange(for: NSRange(location: range.location, length: 0))
        let endLine = nsString.lineRange(for: NSRange(location: range.location + range.length - 1, length: 0))

        var result = ""
        var pos = startLine.location
        while pos <= endLine.location {
            let lr = nsString.lineRange(for: NSRange(location: pos, length: 0))
            result += indent
            result += nsString.substring(with: lr)
            pos = lr.location + lr.length
        }

        textView.insertText(result, replacementRange: NSUnionRange(startLine, endLine))
        let newEnd = startLine.location + result.count
        if range.length > 0 {
            textView.setSelectedRange(NSRange(location: startLine.location, length: newEnd - startLine.location))
        } else {
            textView.setSelectedRange(NSRange(location: range.location + editorTabSize, length: 0))
        }
    }

    func handleUnindent() {
        guard let textView = editorVM.activeTextView else { return }
        let indent = String(repeating: " ", count: editorTabSize)
        let nsString = textView.string as NSString
        let range = textView.selectedRange()
        let startLine = nsString.lineRange(for: NSRange(location: range.location, length: 0))
        let endLine = nsString.lineRange(for: NSRange(location: range.location + range.length - 1, length: 0))

        var result = ""
        var pos = startLine.location
        while pos <= endLine.location {
            let lr = nsString.lineRange(for: NSRange(location: pos, length: 0))
            var line = nsString.substring(with: lr)
            if line.hasPrefix(indent) {
                line = String(line.dropFirst(editorTabSize))
            } else if line.hasPrefix("\t") {
                line = String(line.dropFirst(1))
            }
            result += line
            pos = lr.location + lr.length
        }

        textView.insertText(result, replacementRange: NSUnionRange(startLine, endLine))
    }

    func handleMoveLineUp() {
        guard let textView = editorVM.activeTextView else { return }
        let nsString = textView.string as NSString
        let cursorRange = textView.selectedRange()
        let lineRange = nsString.lineRange(for: NSRange(location: cursorRange.location, length: 0))

        if lineRange.location == 0 { return }

        let prevLineRange = nsString.lineRange(for: NSRange(location: lineRange.location - 1, length: 0))
        let currentLine = nsString.substring(with: lineRange)
        let prevLine = nsString.substring(with: prevLineRange)

        let swapRange = NSRange(location: prevLineRange.location, length: lineRange.length + prevLineRange.length)
        let swapped = currentLine + prevLine

        textView.insertText(swapped, replacementRange: swapRange)
        let newCursorLoc = cursorRange.location - prevLineRange.length
        textView.setSelectedRange(NSRange(location: newCursorLoc, length: cursorRange.length))
    }

    func handleMoveLineDown() {
        guard let textView = editorVM.activeTextView else { return }
        let nsString = textView.string as NSString
        let cursorRange = textView.selectedRange()
        let lineRange = nsString.lineRange(for: NSRange(location: cursorRange.location, length: 0))
        let lineEnd = lineRange.location + lineRange.length

        if lineEnd >= nsString.length { return }

        let nextLineRange = nsString.lineRange(for: NSRange(location: lineEnd, length: 0))
        let currentLine = nsString.substring(with: lineRange)
        let nextLine = nsString.substring(with: nextLineRange)

        let swapRange = NSRange(location: lineRange.location, length: lineRange.length + nextLineRange.length)
        let swapped = nextLine + currentLine

        textView.insertText(swapped, replacementRange: swapRange)
        let newCursorLoc = cursorRange.location + nextLineRange.length
        textView.setSelectedRange(NSRange(location: newCursorLoc, length: cursorRange.length))
    }

    func handleJoinLines() {
        guard let textView = editorVM.activeTextView else { return }
        let nsString = textView.string as NSString
        let cursorRange = textView.selectedRange()

        if cursorRange.length > 0 {
            let selected = nsString.substring(with: cursorRange)
            let joined = selected.replacingOccurrences(of: "\n", with: " ")
            textView.insertText(joined, replacementRange: cursorRange)
        } else {
            let lineRange = nsString.lineRange(for: NSRange(location: cursorRange.location, length: 0))
            let lineEnd = lineRange.location + lineRange.length
            if lineEnd < nsString.length {
                let newlineRange = NSRange(location: lineEnd - 1, length: 1)
                textView.insertText(" ", replacementRange: newlineRange)
            }
        }
    }

    func handleSelectLine() {
        guard let textView = editorVM.activeTextView else { return }
        let nsString = textView.string as NSString
        let cursorRange = textView.selectedRange()
        let lineRange = nsString.lineRange(for: NSRange(location: cursorRange.location, length: 0))
        textView.setSelectedRange(lineRange)
    }

    func handleGoToLine() {
        editorVM.showGoToLine = true
    }

    func handleToggleWordWrap() {
        editorVM.toggleWordWrap()
    }

    func toggleFold(at lineNumber: Int) {
        guard let textView = editorVM.activeTextView else { return }
        let nsString = textView.string as NSString
        let foldID = "\(tabId)-\(lineNumber)"

        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        var currentLine = 1

        nsString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: 0, length: 0))
        while currentLine < lineNumber && lineStart < nsString.length {
            currentLine += 1
            let searchRange = NSRange(location: lineEnd, length: nsString.length - lineEnd)
            if searchRange.length > 0 {
                nsString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: searchRange)
            } else {
                break
            }
        }
        if currentLine != lineNumber { return }

        let lineRange = NSRange(location: lineStart, length: lineEnd - lineStart)
        let lineText = nsString.substring(with: lineRange)

        guard let openBracePos = lineText.firstIndex(of: "{") else { return }
        let braceGlobalPos = lineStart + lineText.distance(from: lineText.startIndex, to: openBracePos)

        let closeBracePos = findMatch(in: nsString, from: braceGlobalPos, open: "{", close: "}", direction: 1)
        guard let closePos = closeBracePos, closePos > braceGlobalPos else { return }

        let foldRange = NSRange(location: braceGlobalPos, length: closePos - braceGlobalPos + 1)

        var foldedSet = editorVM.foldedRanges[tabId] ?? []
        if foldedSet.contains(foldRange) {
            foldedSet.remove(foldRange)
            editorVM.foldedRanges[tabId] = foldedSet
            if let foldedContent = foldedContents[foldID] {
                textView.insertText(foldedContent, replacementRange: foldRange)
                foldedContents.removeValue(forKey: foldID)
            }
        } else {
            let contentToHide = nsString.substring(with: foldRange)
            foldedContents[foldID] = contentToHide
            foldedSet.insert(foldRange)
            editorVM.foldedRanges[tabId] = foldedSet
            textView.insertText("{...}\n", replacementRange: foldRange)
        }
    }

}

// MARK: - Line Number Ruler

class LineNumberRulerView: NSRulerView {
    weak var targetTextView: NSTextView?
    weak var foldCoordinator: EditorNSTextView.Coordinator?
    private let gutterWidth: CGFloat = 48
    private let leftPadding: CGFloat = 8
    private let rightPadding: CGFloat = 6
    private let foldIndicatorSize: CGFloat = 10
    private var foldIndicatorRects: [Int: NSRect] = [:]

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.targetTextView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = gutterWidth
        self.reservedThicknessForMarkers = 0

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textViewFrameChanged),
            name: NSView.frameDidChangeNotification,
            object: textView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textViewFrameChanged(_ notification: Notification) {
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for (lineNumber, rect) in foldIndicatorRects {
            if rect.contains(point) {
                foldCoordinator?.toggleFold(at: lineNumber)
                return
            }
        }
        super.mouseDown(with: event)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        foldIndicatorRects = [:]
        guard let textView = targetTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let visibleRect = textView.visibleRect
        let string = textView.string as NSString
        guard string.length > 0 else { return }

        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        var lineIndex = 1

        let nsFont = textView.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        string.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: 0, length: 0))

        while lineStart < string.length {
            let lineRangeForGlyph = NSRange(location: lineStart, length: lineEnd - lineStart)
            let glyphRangeForLine = layoutManager.glyphRange(forCharacterRange: lineRangeForGlyph, actualCharacterRange: nil)

            var lineRect = layoutManager.boundingRect(forGlyphRange: glyphRangeForLine, in: textContainer)
            lineRect.origin.y += textView.textContainerOrigin.y

            if lineRect.maxY >= visibleRect.minY && lineRect.minY <= visibleRect.maxY {
                let lineContent = string.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))
                let trimmed = lineContent.trimmingCharacters(in: .whitespacesAndNewlines)

                let textFontAttributes: [NSAttributedString.Key: Any] = [
                    .font: nsFont,
                    .foregroundColor: NSColor.tertiaryLabelColor
                ]

                let lineNumber = "\(lineIndex)"
                let textSize = lineNumber.size(withAttributes: textFontAttributes)
                let drawX = gutterWidth - rightPadding - textSize.width
                let drawY = lineRect.minY + (lineRect.height - textSize.height) / 2

                let drawRect = NSRect(x: drawX, y: drawY, width: textSize.width, height: textSize.height)
                lineNumber.draw(in: drawRect, withAttributes: textFontAttributes)

                if trimmed.hasSuffix("{") || trimmed.hasPrefix("{") {
                    let indicatorX: CGFloat = leftPadding
                    let indicatorY = lineRect.minY + (lineRect.height - foldIndicatorSize) / 2
                    let indicatorRect = NSRect(x: indicatorX, y: indicatorY, width: foldIndicatorSize, height: foldIndicatorSize)
                    foldIndicatorRects[lineIndex] = indicatorRect

                    let ctx = NSGraphicsContext.current!.cgContext
                    ctx.setFillColor(NSColor.textSecondary.cgColor)
                    ctx.setStrokeColor(NSColor.clear.cgColor)

                    let midX = indicatorRect.midX
                    let midY = indicatorRect.midY
                    let halfSize = foldIndicatorSize / 2
                    ctx.move(to: CGPoint(x: midX - halfSize + 2, y: midY - halfSize + 2))
                    ctx.addLine(to: CGPoint(x: midX + halfSize - 2, y: midY))
                    ctx.addLine(to: CGPoint(x: midX - halfSize + 2, y: midY + halfSize - 2))
                    ctx.closePath()
                    ctx.fillPath()
                }
            }

            lineIndex += 1
            let searchRange = NSRange(location: lineEnd, length: string.length - lineEnd)
            if searchRange.length > 0 {
                string.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: searchRange)
            } else {
                break
            }
        }
    }
}
