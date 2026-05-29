import SwiftUI
import AppKit

struct JSONBodyEditor: NSViewRepresentable {
    @Binding var text: String
    var onFormat: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.bgTertiary

        let textView = JSONNSTextView()
        textView.editorDelegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = nil
        textView.backgroundColor = NSColor.bgTertiary
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
            textContainer.widthTracksTextView = true
        }

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView

        textView.textStorage?.setAttributedString(highlightJSON(text))

        textView.delegate = context.coordinator

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? JSONNSTextView else { return }

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.textStorage?.setAttributedString(highlightJSON(text))
            if selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onFormat: onFormat)
    }

    private func highlightJSON(_ json: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: json, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.textPrimary
        ])

        guard !json.isEmpty else { return result }

        let nsString = json as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        applyJSONHighlighting(result, string: json, nsString: nsString, range: fullRange)

        return result
    }

    private func applyJSONHighlighting(_ attrStr: NSMutableAttributedString, string: String, nsString: NSString, range: NSRange) {
        enum TokenType {
            case string(Bool) // true = key, false = value
            case number
            case boolean
            case null
            case punctuation
        }

        var pos = range.location
        let end = range.location + range.length

        while pos < end {
            let ch = nsString.character(at: pos)
            let unichar = Character(UnicodeScalar(ch)!)

            if unichar == "\"" {
                let start = pos
                pos += 1
                while pos < end {
                    let c = nsString.character(at: pos)
                    if c == UInt16(unicodeScalar: "\\") {
                        pos += 2
                        continue
                    }
                    if c == UInt16(unicodeScalar: "\"") {
                        pos += 1
                        break
                    }
                    pos += 1
                }
                let stringRange = NSRange(location: start, length: pos - start)

                var isKey = false
                let afterEnd = pos
                var scanPos = afterEnd
                while scanPos < end {
                    let sc = nsString.character(at: scanPos)
                    let sch = Character(UnicodeScalar(sc)!)
                    if sch == ":" {
                        isKey = true
                        break
                    } else if sch == " " || sch == "\t" || sch == "\n" || sch == "\r" {
                        scanPos += 1
                    } else {
                        break
                    }
                }

                let color: NSColor = isKey ? .accentBlue : .syntaxString
                attrStr.addAttribute(.foregroundColor, value: color, range: stringRange)
            } else if unichar == "t" && nsString.length >= pos + 4 {
                let word = nsString.substring(with: NSRange(location: pos, length: 4))
                if word == "true" {
                    attrStr.addAttribute(.foregroundColor, value: NSColor(Color.accentYellow), range: NSRange(location: pos, length: 4))
                    pos += 4
                    continue
                }
                pos += 1
            } else if unichar == "f" && nsString.length >= pos + 5 {
                let word = nsString.substring(with: NSRange(location: pos, length: 5))
                if word == "false" {
                    attrStr.addAttribute(.foregroundColor, value: NSColor(Color.accentYellow), range: NSRange(location: pos, length: 5))
                    pos += 5
                    continue
                }
                pos += 1
            } else if unichar == "n" && nsString.length >= pos + 4 {
                let word = nsString.substring(with: NSRange(location: pos, length: 4))
                if word == "null" {
                    attrStr.addAttribute(.foregroundColor, value: NSColor(Color.accentRed), range: NSRange(location: pos, length: 4))
                    pos += 4
                    continue
                }
                pos += 1
            } else if unichar == "-" || unichar.isNumber() {
                let start = pos
                if unichar == "-" { pos += 1 }
                while pos < end {
                    let nc = nsString.character(at: pos)
                    let nch = Character(UnicodeScalar(nc)!)
                    if nch.isNumber() || nch == "." || nch == "e" || nch == "E" || nch == "+" || nch == "-" {
                        pos += 1
                    } else {
                        break
                    }
                }
                attrStr.addAttribute(.foregroundColor, value: NSColor.accentOrange, range: NSRange(location: start, length: pos - start))
            } else if unichar == "{" || unichar == "}" || unichar == "[" || unichar == "]" || unichar == ":" || unichar == "," {
                attrStr.addAttribute(.foregroundColor, value: NSColor.textTertiary, range: NSRange(location: pos, length: 1))
                pos += 1
            } else {
                pos += 1
            }
        }
    }

    @MainActor
    class Coordinator: NSObject {
        @Binding var text: String
        var onFormat: (() -> Void)?
        private var isUpdating = false

        init(text: Binding<String>, onFormat: (() -> Void)?) {
            self._text = text
            self.onFormat = onFormat
        }
    }
}

extension JSONBodyEditor.Coordinator: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard !isUpdating, let textView = notification.object as? NSTextView else { return }
        isUpdating = true
        text = textView.string
        isUpdating = false
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String?) -> Bool {
        return true
    }
}

private class JSONNSTextView: NSTextView {
    weak var editorDelegate: JSONBodyEditor.Coordinator?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let key = event.charactersIgnoringModifiers else {
            return super.performKeyEquivalent(with: event)
        }

        if key == "f", mods == [.command, .shift] {
            editorDelegate?.onFormat?()
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
    }
}

private extension UInt16 {
    init(unicodeScalar: UnicodeScalar) {
        self.init(unicodeScalar.value)
    }
}

private extension Character {
    func isNumber() -> Bool {
        self >= "0" && self <= "9"
    }
}
