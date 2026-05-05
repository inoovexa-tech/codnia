import SwiftUI

struct CodeEditorView: View {
    @Binding var content: String
    let language: String
    let onChange: () -> Void
    @EnvironmentObject var settings: SettingsService
    @State private var showDebug = true

    var body: some View {
        ZStack {
            // The NSTextView editor
            EditorNSTextView(
                text: $content,
                fontSize: settings.fontSize,
                onChange: onChange
            )

            // Debug overlay to verify data flow (triple-click to toggle)
            if showDebug && content.count > 0 {
                VStack {
                    HStack {
                        Text("\(content.count) chars")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                            .padding(4)
                            .background(Color.black.opacity(0.8))
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            print("CodeEditorView appeared")
            print("Content length: \(content.count)")
            print("Content preview: \(content.prefix(100))")
        }
        .onTapGesture(count: 3) {
            showDebug.toggle()
        }
    }
}

struct EditorNSTextView: NSViewRepresentable {
    @Binding var text: String
    let fontSize: Double
    let onChange: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        print("=== makeNSView ===")
        print("Text length: \(text.count)")
        print("Text preview: \(text.prefix(50))")

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.black

        let textView = NSTextView()
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        textView.textColor = NSColor.white
        textView.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        textView.insertionPointColor = NSColor.systemBlue
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.blue.withAlphaComponent(0.5),
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
        print("=== makeNSView: textView.string set, length = \(textView.string.count)")

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        print("=== updateNSView ===")
        print("textView.string length: \(textView.string.count)")
        print("binding text length: \(text.count)")

        if textView.string != text {
            print("Updating text in NSTextView")
            let selected = textView.selectedRange()
            textView.string = text
            if selected.location <= text.count && selected.location >= 0 {
                textView.setSelectedRange(selected)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onChange: onChange)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        let onChange: () -> Void

        init(text: Binding<String>, onChange: @escaping () -> Void) {
            self._text = text
            self.onChange = onChange
            print("=== Coordinator init ===")
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            onChange()
        }
    }
}
