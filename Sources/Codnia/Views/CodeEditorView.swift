import SwiftUI

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

struct EditorNSTextView: NSViewRepresentable {
    @Binding var text: String
    let fontSize: Double
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

        let textView = NSTextView()
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

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
        }

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.postsFrameChangedNotifications = true

        scrollView.documentView = textView

        textView.textStorage?.setAttributedString(NSAttributedString(string: text))

        textView.delegate = context.coordinator

        context.coordinator.updateHighlighter(language: language)
        context.coordinator.applyHighlighting(textView)

        context.coordinator.configureScrollObserver(scrollView: scrollView)
        if editorVM.activeTextView !== textView { editorVM.activeTextView = textView }
        restoreSavedState(textView: textView, scrollView: scrollView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

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
        context.coordinator.highlightSearchResults(textView, results: searchResults, currentIndex: currentSearchIndex)
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

    class Coordinator: NSObject {
        @Binding var text: String
        let onChange: () -> Void
        let tabId: String
        let editorVM: EditorViewModel
        var highlighter: SyntaxHighlighter?
        var currentLanguage: String = ""
        private var scrollObserver: NSObjectProtocol?
        private var searchHighlightColor = NSColor(red: 255/255, green: 213/255, blue: 0/255, alpha: 0.3)
        private var currentHighlightColor = NSColor(red: 255/255, green: 140/255, blue: 0/255, alpha: 0.5)

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
            guard let highlighter = highlighter,
                  let textStorage = textView.textStorage else { return }
            highlighter.highlight(textStorage)
            if let layoutManager = textView.layoutManager {
                let fullRange = NSRange(location: 0, length: textStorage.length)
                layoutManager.invalidateDisplay(forCharacterRange: fullRange)
            }
            textView.needsDisplay = true
        }

        @MainActor func highlightSearchResults(_ textView: NSTextView, results: [NSRange], currentIndex: Int) {
            guard let textStorage = textView.textStorage else { return }

            textStorage.beginEditing()
            textStorage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: textStorage.length))

            for (index, range) in results.enumerated() {
                let color = index == currentIndex ? currentHighlightColor : searchHighlightColor
                textStorage.addAttribute(.backgroundColor, value: color, range: range)
            }

            textStorage.endEditing()

            if currentIndex < results.count {
                scrollToRange(textView, range: results[currentIndex])
            }
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

extension EditorNSTextView.Coordinator: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        text = textView.string
        applyHighlighting(textView)
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
    }
}


