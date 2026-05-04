import SwiftUI
import Runestone

struct CodeEditorView: View {
    @Binding var content: String
    let language: String
    let onChange: () -> Void
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        RunestoneEditor(
            text: $content,
            fontSize: settings.fontSize,
            showLineNumbers: settings.showLineNumbers,
            onTextChange: onChange
        )
        .background(Color.bgPrimary)
    }
}

struct RunestoneEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: Double
    let showLineNumbers: Bool
    let onTextChange: () -> Void

    func makeNSView(context: Context) -> TextView {
        let textView = TextView()
        textView.autoresizingMask = [.width, .height]
        textView.isLineWrappingEnabled = true
        textView.showLineNumbers = showLineNumbers
        textView.editorConfig.textColor = .textPrimary
        textView.gutterBackgroundColor = .bgPrimary
        textView.gutterTextColor = .textSecondary
        textView.backgroundColor = .bgPrimary
        textView.editorConfig.font = NSFont(name: "SF Mono", size: CGFloat(fontSize)) ?? NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        textView.editorConfig.highlightedLineColor = NSColor(Color.lineHighlight)
        textView.editorConfig.selectedTextBackgroundColor = NSColor(Color.selectionBg)
        textView.editorConfig.insertionPointColor = .accentBlue

        // Theme colors
        textView.editorConfig.textColor = NSColor(Color.textPrimary)

        textView.string = text
        textView.delegate = context.coordinator
        return textView
    }

    func updateNSView(_ nsView: TextView, context: Context) {
        if nsView.string != text {
            nsView.string = text
        }
        nsView.showLineNumbers = showLineNumbers
        if let font = NSFont(name: "SF Mono", size: CGFloat(fontSize)) {
            nsView.editorConfig.font = font
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, TextViewDelegate {
        let parent: RunestoneEditor

        init(_ parent: RunestoneEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: TextView) {
            parent.text = textView.string
            parent.onTextChange()
        }

        func textViewDidChangeSelection(_ textView: TextView) {
            // Track cursor position
        }
    }
}
