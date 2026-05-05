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
                    .onAppear {
                        print("EditorAreaView: showing editor for tab: \(activeTab.name)")
                        print("EditorAreaView: content length: \(editorVM.editorContent.count)")
                        print("EditorAreaView: content preview: \(editorVM.editorContent.prefix(50))")
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

            Text("Open a file to start editing")
                .font(.system(size: 13))
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}
