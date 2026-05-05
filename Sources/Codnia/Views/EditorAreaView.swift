import SwiftUI

struct EditorAreaView: View {
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var terminalVM: TerminalViewModel
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        Group {
            if let activeTab = editorVM.currentTab {
                if activeTab.type == .file {
                    CodeEditorView(
                        content: $editorVM.editorContent,
                        language: editorVM.currentLanguage,
                        onChange: {
                            editorVM.markModified(tabId: activeTab.id)
                        }
                    )
                    .environmentObject(settings)
                    .id("editor-\(activeTab.id)")
                    .onAppear {
                        // Ensure editor is focusable when tab becomes active
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            if let window = NSApplication.shared.keyWindow {
                                if let scrollView = window.contentView?.findSubview(ofType: NSScrollView.self),
                                   let textView = scrollView.documentView as? NSTextView {
                                    window.makeFirstResponder(textView)
                                }
                            }
                        }
                    }
                } else if let tab = terminalVM.tabs.first(where: { $0.id == activeTab.id }) {
                    TerminalView(tab: tab)
                        .environmentObject(terminalVM)
                        .background(Color.bgPrimary)
                } else {
                    EmptyStateView()
                }
            } else {
                EmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.textTertiary)
                .opacity(0.3)

            Text("Open a file to start editing")
                .font(.system(size: 13))
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}
