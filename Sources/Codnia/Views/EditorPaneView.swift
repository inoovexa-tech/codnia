import SwiftUI

struct EditorPaneView: View {
    let leaf: SplitLeaf
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var terminalVM: TerminalViewModel
    @EnvironmentObject var splitVM: SplitViewModel
    @EnvironmentObject var settings: SettingsService
    @EnvironmentObject var appState: AppState

    @State private var isHovered = false

    private var tab: Tab? {
        let all = editorVM.tabs + terminalVM.tabs
        return all.first { $0.id == leaf.tabId }
    }

    private var isActivePane: Bool {
        leaf.id == splitVM.activePaneId
    }

    var body: some View {
        ZStack {
            contentView

            if splitVM.root.leafCount > 1 && tab?.type != .browser {
                VStack {
                    HStack {
                        Spacer()
                        paneControls
                    }
                    .padding(4)
                    Spacer()
                }
            }
        }
        .onTapGesture { activatePane() }
        .background(Color.bgPrimary)
        .overlay(
            Rectangle()
                .stroke(isActivePane ? Color(hex: "#3a3a3a") : Color.borderLight, lineWidth: isActivePane ? 1 : 0.5)
        )
    }

    @ViewBuilder
    private var contentView: some View {
        if let tab = tab {
            switch tab.type {
            case .file:
                if editorVM.isCurrentTabMarkdown && editorVM.showMarkdownPreview && isActivePane {
                    MarkdownPreviewView(content: editorVM.editorContent)
                } else if editorVM.isCurrentTabHTML && editorVM.showHTMLPreview && isActivePane {
                    HTMLPreviewView(content: editorVM.editorContent)
                } else if isActivePane {
                    CodeEditorView(
                        content: $editorVM.editorContent,
                        language: editorVM.currentLanguage,
                        onChange: { editorVM.markModified(tabId: tab.id) },
                        searchResults: [],
                        currentSearchIndex: 0
                    )
                    .environmentObject(settings)
                } else {
                    readOnlyFileView(tab: tab)
                }

            case .terminal, .opencode, .claude, .codex:
                TerminalSingleView(viewId: leaf.id, fontSize: settings.terminalFontSize)
                    .id(leaf.tabId ?? leaf.id.uuidString)

            case .diff:
                if let diffLines = editorVM.diffData[tab.id] {
                    DiffView(diffLines: diffLines, fileName: tab.name)
                } else {
                    EmptyDiffView()
                }

            case .image:
                ImagePreviewView(path: tab.path)

            case .pdf:
                PDFPreviewView(path: tab.path)

            case .queryResult:
                QueryResultTabView(tabId: tab.id)

            case .restApi:
                RESTApiTabView(tabId: tab.id, restApiRequestId: tab.restApiRequestId)

            case .browser:
                BrowserView(
                    tabId: tab.id,
                    urlString: Binding(
                        get: { editorVM.browserURLs[tab.id] ?? tab.url ?? "about:blank" },
                        set: { editorVM.updateBrowserURL(tabId: tab.id, url: $0) }
                    ),
                    pageTitle: Binding(
                        get: { editorVM.browserTitles[tab.id] ?? "" },
                        set: { editorVM.updateBrowserTitle(tabId: tab.id, title: $0) }
                    ),
                    onNavigate: { url in
                        editorVM.updateBrowserURL(tabId: tab.id, url: url)
                    },
                    onClose: {
                        editorVM.closeTab(tab.id)
                    },
                    onPinToLeft: {
                        let url = editorVM.browserURLs[tab.id] ?? tab.url ?? "about:blank"
                        appState.openURL(url, in: .leftPanel)
                        editorVM.closeTab(tab.id)
                    },
                    onPinToRight: {
                        let url = editorVM.browserURLs[tab.id] ?? tab.url ?? "about:blank"
                        appState.openURL(url, in: .rightPanel)
                        editorVM.closeTab(tab.id)
                    }
                )
            }
        } else {
            emptyTabView
        }
    }

    private func readOnlyFileView(tab: Tab) -> some View {
        let content = editorVM.fileContents[tab.id] ?? ""
        return ScrollView([.horizontal, .vertical]) {
            Text(content)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
        }
        .background(Color.bgPrimary)
        .allowsHitTesting(false)
    }

    private var paneControls: some View {
        HStack(spacing: 2) {
            Button {
                splitVM.splitPane(leaf.id, direction: .horizontal, editorVM: editorVM, terminalVM: terminalVM)
            } label: {
                Image(systemName: "square.split.2x1")
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
                    .padding(4)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Split left/right")

            Button {
                splitVM.splitPane(leaf.id, direction: .vertical, editorVM: editorVM, terminalVM: terminalVM)
            } label: {
                Image(systemName: "square.split.1x2")
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
                    .padding(4)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Split top/bottom")

            Button {
                splitVM.closePane(leaf.id, editorVM: editorVM, terminalVM: terminalVM)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .padding(4)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Close pane")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color.bgTertiary.opacity(0.85))
        .cornerRadius(4)
        .opacity(isHovered ? 1 : 0.3)
        .onHover { isHovered = $0 }
    }

    private var emptyTabView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundColor(.textTertiary)
            Text("No file open")
                .font(.system(size: 12))
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func activatePane() {
        guard leaf.id != splitVM.activePaneId else { return }
        splitVM.activePaneId = leaf.id
    }
}
