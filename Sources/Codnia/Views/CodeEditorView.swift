import SwiftUI

struct CodeEditorView: View {
    @Binding var content: String
    let language: String
    let onChange: () -> Void
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        ZStack {
            EditorNSTextView(
                text: $content,
                fontSize: settings.fontSize,
                language: language,
                onChange: onChange
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
        textView.textColor = NSColor.textPrimary
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

        context.coordinator.updateHighlighter(language: language)

        if textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
            if selected.location <= text.count && selected.location >= 0 {
                textView.setSelectedRange(selected)
            }
        }

        context.coordinator.applyHighlighting(textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, language: language, onChange: onChange)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        let onChange: () -> Void
        var highlighter: SyntaxHighlighter?
        private var isHighlighting = false

        init(text: Binding<String>, language: String, onChange: @escaping () -> Void) {
            self._text = text
            self.onChange = onChange
            self.highlighter = SyntaxHighlighter(language: language)
        }

        func updateHighlighter(language: String) {
            highlighter = SyntaxHighlighter(language: language)
        }

        @MainActor func applyHighlighting(_ textView: NSTextView) {
            guard !isHighlighting, let highlighter = highlighter,
                  let textStorage = textView.textStorage else { return }
            isHighlighting = true
            highlighter.highlight(textStorage)
            isHighlighting = false
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            onChange()
            applyHighlighting(textView)
        }
    }
}
