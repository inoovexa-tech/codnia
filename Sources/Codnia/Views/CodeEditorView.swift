import SwiftUI

struct CodeEditorView: View {
    @Binding var content: String
    let language: String
    let onChange: () -> Void
    var searchResults: [NSRange] = []
    var currentSearchIndex: Int = 0
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        ZStack {
            EditorNSTextView(
                text: $content,
                fontSize: settings.fontSize,
                language: language,
                onChange: onChange,
                searchResults: searchResults,
                currentSearchIndex: currentSearchIndex
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
        textView.delegate = context.coordinator

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
        }

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView

        textView.string = text

        context.coordinator.updateHighlighter(language: language)
        context.coordinator.applyHighlighting(textView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        let languageChanged = context.coordinator.currentLanguage != language
        context.coordinator.updateHighlighter(language: language)

        let textChanged = textView.string != text
        if textChanged {
            let selected = textView.selectedRange()
            textView.string = text
            if selected.location <= text.count && selected.location >= 0 {
                textView.setSelectedRange(selected)
            }
        }

        if languageChanged || textChanged {
            context.coordinator.applyHighlighting(textView)
        }
        context.coordinator.highlightSearchResults(textView, results: searchResults, currentIndex: currentSearchIndex)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, language: language, onChange: onChange)
    }

    class Coordinator: NSObject {
        @Binding var text: String
        let onChange: () -> Void
        var highlighter: SyntaxHighlighter?
        var currentLanguage: String = ""
        private var isHighlighting = false
        private var searchHighlightColor = NSColor(red: 255/255, green: 213/255, blue: 0/255, alpha: 0.3)
        private var currentHighlightColor = NSColor(red: 255/255, green: 140/255, blue: 0/255, alpha: 0.5)

        init(text: Binding<String>, language: String, onChange: @escaping () -> Void) {
            self._text = text
            self.onChange = onChange
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
    }
}

extension EditorNSTextView.Coordinator: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        text = textView.string
        applyHighlighting(textView)
        onChange()
    }
}
