import SwiftUI

struct EditorAreaView: View {
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var terminalVM: TerminalViewModel
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        ZStack {
            // File editor
            if let activeTab = editorVM.currentTab, activeTab.type == .file {
                CodeEditorView(
                    content: $editorVM.editorContent,
                    language: editorVM.currentLanguage,
                    onChange: {
                        editorVM.markModified(tabId: activeTab.id)
                    }
                )
                .environmentObject(settings)
            }

            // Terminals - persistent container keeps sessions alive across tab/project switches
            TerminalView(
                tabs: $terminalVM.tabs,
                activeTabId: $editorVM.activeTabId
            )
            .opacity(terminalVisibility)

            if editorVM.currentTab == nil {
                EmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }

    private var terminalVisibility: Double {
        guard let activeTab = editorVM.currentTab else { return 0 }
        return terminalVM.tabs.contains { $0.id == activeTab.id } ? 1 : 0
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
