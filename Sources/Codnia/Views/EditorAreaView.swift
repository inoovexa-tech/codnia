import SwiftUI

struct EditorAreaView: View {
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var terminalVM: TerminalViewModel
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        ZStack {
            if editorVM.tabs.isEmpty && terminalVM.tabs.isEmpty {
                EmptyStateView()
            } else if let activeId = editorVM.activeTabId {
                // Look in editor tabs first, then terminal tabs
                if let _ = editorVM.tabs.first(where: { $0.id == activeId }) {
                    CodeEditorView(
                        content: $editorVM.editorContent,
                        language: editorVM.currentLanguage,
                        onChange: {
                            editorVM.markModified(tabId: activeId)
                        }
                    )
                    .environmentObject(settings)
                } else if let tab = terminalVM.tabs.first(where: { $0.id == activeId }) {
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
