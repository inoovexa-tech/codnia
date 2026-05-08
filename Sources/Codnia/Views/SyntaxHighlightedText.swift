import SwiftUI
import AppKit

/// A view that displays syntax-highlighted text using the same colors as CodeEditorView.
/// Built on top of SyntaxHighlighter so the diff uses identical highlighting.
struct SyntaxHighlightedText: View {
    let text: String
    let language: String
    let opacity: Double
    let isStrikethrough: Bool

    init(text: String, language: String, opacity: Double = 1.0, isStrikethrough: Bool = false) {
        self.text = text
        self.language = language
        self.opacity = opacity
        self.isStrikethrough = isStrikethrough
    }

    var body: some View {
        SyntaxHighlightedTextView(
            text: text,
            language: language,
            fontSize: 12,
            opacity: opacity,
            isStrikethrough: isStrikethrough
        )
    }
}

// MARK: - NSView Bridge for Syntax Highlighting

struct SyntaxHighlightedTextView: NSViewRepresentable {
    let text: String
    let language: String
    let fontSize: Double
    let opacity: Double
    let isStrikethrough: Bool

    func makeNSView(context: Context) -> NSView {
        // Container view with opacity
        let container = NSView()
        container.wantsLayer = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textView.topAnchor.constraint(equalTo: container.topAnchor),
            textView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.textView = textView
        updateContent(textView)

        // Apply opacity to container
        container.alphaValue = CGFloat(opacity)

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        updateContent(textView)
        nsView.alphaValue = CGFloat(opacity)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        weak var textView: NSTextView?
    }

    private func updateContent(_ textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.beginEditing()

        // Clear and set base text
        textStorage.deleteCharacters(in: fullRange)
        textStorage.append(NSAttributedString(string: text))

        // Base styling
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular),
            .foregroundColor: NSColor.textPrimary,
        ]
        textStorage.setAttributes(baseAttributes, range: NSRange(location: 0, length: textStorage.length))

        if isStrikethrough {
            textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: textStorage.length))
            textStorage.addAttribute(.strikethroughColor, value: NSColor.textSecondary, range: NSRange(location: 0, length: textStorage.length))
        }

        // Apply syntax highlighting
        let highlighter = SyntaxHighlighter(language: language)
        highlighter.highlight(textStorage)

        textStorage.endEditing()
    }
}
