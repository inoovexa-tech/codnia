import SwiftUI
import UniformTypeIdentifiers

struct EditorAreaView: View {
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var terminalVM: TerminalViewModel
    @EnvironmentObject var settings: SettingsService
    @EnvironmentObject var databaseService: DatabaseConnectionService
    @EnvironmentObject var appState: AppState

    private var isTerminalVisible: Bool {
        guard let activeTab = editorVM.currentTab else { return false }
        return terminalVM.tabs.contains { $0.id == activeTab.id }
    }

    @State private var inFileSearchQuery: String = ""
    @State private var inFileSearchResults: [NSRange] = []
    @State private var inFileSearchCurrentIndex: Int = 0
    @FocusState private var inFileSearchFocused: Bool

    var body: some View {
        ZStack {
            // Terminals - always rendered at back layer; sessions stay alive via TerminalManager singleton
            TerminalView(
                tabs: $terminalVM.tabs,
                activeTabId: $editorVM.activeTabId
            )
            .allowsHitTesting(isTerminalVisible)

            // Diff viewer for diff tabs
            if let activeTab = editorVM.currentTab, activeTab.type == .diff {
                if let diffLines = editorVM.diffData[activeTab.id] {
                    DiffView(diffLines: diffLines, fileName: activeTab.name)
                } else {
                    EmptyDiffView()
                }
            }

            // Image preview
            if let activeTab = editorVM.currentTab, activeTab.type == .image {
                ImagePreviewView(path: activeTab.path)
            }

            // PDF preview
            if let activeTab = editorVM.currentTab, activeTab.type == .pdf {
                PDFPreviewView(path: activeTab.path)
            }

            // Query result tab
            if let activeTab = editorVM.currentTab, activeTab.type == .queryResult {
                QueryResultTabView(tabId: activeTab.id)
            }

            // Browser tab
            if let activeTab = editorVM.currentTab, activeTab.type == .browser {
                BrowserView(
                    tabId: activeTab.id,
                    urlString: Binding(
                        get: { editorVM.browserURLs[activeTab.id] ?? activeTab.url ?? "about:blank" },
                        set: { editorVM.updateBrowserURL(tabId: activeTab.id, url: $0) }
                    ),
                    pageTitle: Binding(
                        get: { editorVM.browserTitles[activeTab.id] ?? "" },
                        set: { editorVM.updateBrowserTitle(tabId: activeTab.id, title: $0) }
                    ),
                    onNavigate: { url in
                        editorVM.updateBrowserURL(tabId: activeTab.id, url: url)
                    },
                    onClose: {
                        editorVM.closeTab(activeTab.id)
                    },
                    onPinToLeft: {
                        let url = editorVM.browserURLs[activeTab.id] ?? activeTab.url ?? "about:blank"
                        appState.browserURL = url
                        appState.browserSide = .left
                        appState.browserExpanded = true
                        editorVM.closeTab(activeTab.id)
                    },
                    onPinToRight: {
                        let url = editorVM.browserURLs[activeTab.id] ?? activeTab.url ?? "about:blank"
                        appState.browserURL = url
                        appState.browserSide = .right
                        appState.browserExpanded = true
                        editorVM.closeTab(activeTab.id)
                    }
                )
            }

            // File editor
            if let activeTab = editorVM.currentTab, activeTab.type == .file {
                if editorVM.isCurrentTabMarkdown && editorVM.showMarkdownPreview {
                    MarkdownPreviewView(content: editorVM.editorContent)
                } else {
                    let hasInFileSearch = editorVM.showInFileSearch || !inFileSearchResults.isEmpty
                    let activeSearchResults = hasInFileSearch ? inFileSearchResults : editorVM.searchHighlightRanges
                    let activeSearchIndex = hasInFileSearch ? inFileSearchCurrentIndex : editorVM.searchHighlightIndex
                    CodeEditorView(
                        content: $editorVM.editorContent,
                        language: editorVM.currentLanguage,
                        onChange: {
                            editorVM.markModified(tabId: activeTab.id)
                        },
                        searchResults: activeSearchResults,
                        currentSearchIndex: activeSearchIndex
                    )
                    .environmentObject(settings)
                }
            }

            // In-file search bar
            if editorVM.showInFileSearch {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(.textTertiary)

                        TextField("Find in file", text: $inFileSearchQuery)
                            .font(.system(size: 12))
                            .foregroundColor(.textPrimary)
                            .textFieldStyle(PlainTextFieldStyle())
                            .frame(width: 200)
                            .focused($inFileSearchFocused)
                            .onAppear {
                                inFileSearchFocused = true
                            }
                            .onSubmit {
                                if inFileSearchResults.count > 1 {
                                    performInFileSearchNext()
                                } else {
                                    performInFileSearch()
                                }
                            }
                            .onChange(of: inFileSearchQuery) { _ in
                                performInFileSearch()
                            }

                        if !inFileSearchQuery.isEmpty {
                            Text("\(inFileSearchResults.isEmpty ? 0 : inFileSearchCurrentIndex + 1)/\(inFileSearchResults.count)")
                                .font(.system(size: 11))
                                .foregroundColor(.textTertiary)
                        }

                        Button(action: performInFileSearchPrevious) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() }
                            else { NSCursor.pop() }
                        }
                        .disabled(inFileSearchResults.isEmpty)

                        Button(action: performInFileSearchNext) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() }
                            else { NSCursor.pop() }
                        }
                        .disabled(inFileSearchResults.isEmpty)

                        Button(action: {
                            editorVM.showInFileSearch = false
                            inFileSearchQuery = ""
                            inFileSearchResults = []
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() }
                            else { NSCursor.pop() }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.bgSecondary)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.borderLight, lineWidth: 0.5)
                    )

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 8)
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
            }

            if editorVM.currentTab == nil {
                EmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
        .onDrop(of: [.text, .fileURL], isTargeted: nil) { providers in
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        var path: String?
                        if let url = item as? URL {
                            path = url.path
                        } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            path = url.path
                        }
                        guard let text = path else { return }
                        DispatchQueue.main.async {
                            self.pasteToTerminal(text: text)
                        }
                    }
                } else {
                    provider.loadObject(ofClass: NSString.self) { object, _ in
                        guard let text = object as? String else { return }
                        DispatchQueue.main.async {
                            self.pasteToTerminal(text: text)
                        }
                    }
                }
            }
            return true
        }
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

    private func pasteToTerminal(text: String) {
        guard let tab = self.editorVM.currentTab else { return }
        if let termId = tab.terminalId, self.terminalVM.tabs.contains(where: { $0.id == tab.id }) {
            TerminalManager.shared.paste(id: termId, text: text)
        } else {
            self.editorVM.newFile(name: text, content: text)
        }
    }

    private func performInFileSearch() {
        guard !inFileSearchQuery.isEmpty else {
            inFileSearchResults = []
            return
        }
        let content = editorVM.editorContent as NSString
        var ranges: [NSRange] = []
        let searchRange = NSRange(location: 0, length: content.length)
        content.enumerateSubstrings(in: searchRange, options: .byLines) { substring, lineRange, _, _ in
            if let line = substring {
                var searchStart = 0
                while searchStart < line.count {
                    let range = (line as NSString).range(of: self.inFileSearchQuery, options: .caseInsensitive, range: NSRange(location: searchStart, length: line.count - searchStart))
                    if range.location == NSNotFound { break }
                    let fullRange = NSRange(location: lineRange.location + range.location, length: range.length)
                    ranges.append(fullRange)
                    searchStart = lineRange.location + range.location + range.length
                }
            }
        }
        inFileSearchResults = ranges
        inFileSearchCurrentIndex = ranges.isEmpty ? 0 : 0
    }

    private func performInFileSearchNext() {
        guard !inFileSearchResults.isEmpty else { return }
        inFileSearchCurrentIndex = (inFileSearchCurrentIndex + 1) % inFileSearchResults.count
    }

    private func performInFileSearchPrevious() {
        guard !inFileSearchResults.isEmpty else { return }
        inFileSearchCurrentIndex = inFileSearchCurrentIndex == 0 ? inFileSearchResults.count - 1 : inFileSearchCurrentIndex - 1
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
