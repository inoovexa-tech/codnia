import SwiftUI
import AppKit

struct SQLTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onSelectionChange: (String) -> Void
    var completionProvider: SQLCompletionProvider?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let tv = NSTextView()
        tv.isEditable = true
        tv.isSelectable = true
        tv.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.backgroundColor = .clear
        tv.textColor = NSColor.textColor
        tv.insertionPointColor = NSColor.textColor
        tv.delegate = context.coordinator
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        tv.autoresizingMask = [.width]
        tv.allowsUndo = true
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.isAutomaticDataDetectionEnabled = false
        tv.isAutomaticTextCompletionEnabled = false

        scrollView.documentView = tv
        context.coordinator.textView = tv

        context.coordinator.highlighter = SyntaxHighlighter(language: "sql")
        context.coordinator.applyHighlighting()

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = nsView.documentView as? NSTextView else { return }
        if tv.string != text {
            tv.string = text
            context.coordinator.applyHighlighting()
        }
        context.coordinator.parent = self
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SQLTextEditor
        weak var textView: NSTextView?
        var highlighter: SyntaxHighlighter?

        init(_ parent: SQLTextEditor) {
            self.parent = parent
        }

        @MainActor
        func applyHighlighting() {
            guard let tv = textView, let highlighter = highlighter,
                  let storage = tv.textStorage else { return }
            highlighter.highlight(storage)
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.text = tv.string
            applyHighlighting()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = textView else { return }
            let range = tv.selectedRange()
            if range.length > 0 {
                let sel = (tv.string as NSString).substring(with: range)
                parent.onSelectionChange(sel)
            } else {
                parent.onSelectionChange("")
            }
        }

        func textView(_ textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String] {
            guard let provider = parent.completionProvider else { return words }
            let partial = (textView.string as NSString).substring(with: charRange)
            let items = provider.items(matching: partial)
            if items.isEmpty { return words }
            return items.map { $0.displayText }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.complete(_:)) {
                return false
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                return false
            }
            return false
        }

        func textViewDidChangeTypingAttributes(_ notification: Notification) {
        }
    }
}
