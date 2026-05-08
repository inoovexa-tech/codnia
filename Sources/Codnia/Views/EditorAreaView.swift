import SwiftUI

struct EditorAreaView: View {
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var terminalVM: TerminalViewModel
    @EnvironmentObject var settings: SettingsService

    private var isTerminalVisible: Bool {
        guard let activeTab = editorVM.currentTab else { return false }
        return terminalVM.tabs.contains { $0.id == activeTab.id }
    }

    var body: some View {
        ZStack {
            // Diff viewer for diff tabs
            if let activeTab = editorVM.currentTab, activeTab.type == .diff {
                if let diffLines = editorVM.diffData[activeTab.id] {
                    DiffView(diffLines: diffLines, fileName: activeTab.name)
                        .allowsHitTesting(!isTerminalVisible)
                } else {
                    EmptyDiffView()
                }
            }

            // File editor
            if let activeTab = editorVM.currentTab, activeTab.type == .file {
                if editorVM.isCurrentTabMarkdown && editorVM.showMarkdownPreview {
                    MarkdownPreviewView(content: editorVM.editorContent)
                        .allowsHitTesting(!isTerminalVisible)
                } else {
                    CodeEditorView(
                        content: $editorVM.editorContent,
                        language: editorVM.currentLanguage,
                        onChange: {
                            editorVM.markModified(tabId: activeTab.id)
                        }
                    )
                    .environmentObject(settings)
                    .allowsHitTesting(!isTerminalVisible)
                }
            }

            // Preview toggle for markdown files
            if let activeTab = editorVM.currentTab,
               activeTab.type == .file,
               editorVM.isCurrentTabMarkdown {
                VStack {
                    HStack {
                        Spacer()
                        markdownToggleButton
                            .padding(.trailing, 20)
                            .padding(.top, 8)
                    }
                    Spacer()
                }
                .allowsHitTesting(!isTerminalVisible)
            }

            // Terminals - persistent container keeps sessions alive across tab/project switches
            TerminalView(
                tabs: $terminalVM.tabs,
                activeTabId: $editorVM.activeTabId
            )
            .opacity(terminalVisibility)
            .allowsHitTesting(isTerminalVisible)

            if editorVM.currentTab == nil {
                EmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }

    private var markdownToggleButton: some View {
        HStack(spacing: 4) {
            Image(systemName: editorVM.showMarkdownPreview ? "doc.plaintext" : "eye")
                .font(.system(size: 11, weight: .medium))
            Text(editorVM.showMarkdownPreview ? "Code" : "Preview")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.bgTertiary.opacity(0.6))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.borderLight.opacity(0.5), lineWidth: 0.5)
        )
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                editorVM.showMarkdownPreview.toggle()
            }
        }
        .help(editorVM.showMarkdownPreview ? "Show code editor" : "Show markdown preview")
    }

    private var terminalVisibility: Double {
        guard let activeTab = editorVM.currentTab else { return 0 }
        return terminalVM.tabs.contains { $0.id == activeTab.id } ? 1 : 0
    }
}

struct EmptyDiffView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.forwardslash.minus")
                .font(.system(size: 48))
                .foregroundColor(.textTertiary)

            Text("No diff available")
                .font(.system(size: 13))
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0d1117"))
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
