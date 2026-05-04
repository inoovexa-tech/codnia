import SwiftUI

struct EditorAreaView: View {
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var terminalVM: TerminalViewModel
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        ZStack {
            if editorVM.allTabs.isEmpty || editorVM.activeTabId == nil {
                EmptyStateView()
            } else if let tab = editorVM.currentTab {
                switch tab.type {
                case .file:
                    CodeEditorView(
                        content: $editorVM.editorContent,
                        language: editorVM.currentLanguage,
                        onChange: {
                            editorVM.markModified(tabId: tab.id)
                        }
                    )
                    .environmentObject(settings)
                default:
                    TerminalView(tab: tab)
                        .environmentObject(terminalVM)
                        .background(Color.bgPrimary)
                }
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
