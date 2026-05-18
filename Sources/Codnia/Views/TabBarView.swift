import SwiftUI
import AppKit

struct TabBarView: View {
    @ObservedObject var editorVM: EditorViewModel
    @ObservedObject var terminalVM: TerminalViewModel
    @ObservedObject var splitVM: SplitViewModel
    @ObservedObject var workspaceVM: WorkspaceService
    @ObservedObject var settings: SettingsService

    var onToggleRightSidebar: () -> Void
    var isRightSidebarExpanded: Bool
    var isDatabaseEnabled: Bool = false
    var onNewSQLQuery: () -> Void = {}

    var onToggleExplorer: () -> Void = {}
    var onToggleSearch: () -> Void = {}
    var onToggleSourceControl: () -> Void = {}
    var onOpenBrowser: (() -> Void)?

    @State private var draggedTabId: String?
    @State private var showTabDropdown = false
    @State private var interactiveFrames: [CGRect] = []
    @ObservedObject private var shortcutsService = KeyboardShortcutsService.shared

    private var allTabs: [Tab] {
        editorVM.tabs + terminalVM.tabs
    }

    private var allWorktreesExpanded: Bool {
        !workspaceVM.projects.isEmpty && workspaceVM.projects.allSatisfy(\.isWorktreesExpanded)
    }

    private var isExplorerActive: Bool {
        false
    }

    private var isSearchActive: Bool {
        false
    }

    private var isSourceControlActive: Bool {
        false
    }

    @ViewBuilder
    private var navButtons: some View {
        HStack(spacing: 4) {
            Button(action: { workspaceVM.previousProject() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13))
                    .frame(width: 28, height: 36)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textSecondary)
            .disabled(workspaceVM.projects.count <= 1)
            .trackInteractiveFrame()

            Button(action: { workspaceVM.nextProject() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .frame(width: 28, height: 36)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textSecondary)
            .disabled(workspaceVM.projects.count <= 1)
            .trackInteractiveFrame()
        }
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: 90)

                    if !workspaceVM.projects.isEmpty {
                        if settings.leftSidebarExpanded {
                            HStack(spacing: 0) {
                                Spacer(minLength: 0)
                                HStack(spacing: 4) {
                                    Button(action: toggleAllWorktrees) {
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 10))
                                            .frame(width: 28, height: 36)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .foregroundColor(.textSecondary)
                                    .trackInteractiveFrame()

                                    navButtons
                                }
                                .padding(.trailing, 6)
                            }
                        } else {
                            navButtons
                                .padding(.leading, 4)
                        }
                    }
                }
                .frame(width: settings.leftSidebarExpanded ? max(settings.leftSidebarWidth - 1, 0) : nil, alignment: .leading)

                Rectangle()
                    .frame(width: 1)
                    .foregroundColor(.borderDefault)

                Menu {
                    menuItem("New File", shortcutKey: "newFile") { editorVM.newFile() }
                    menuItem("New Terminal", shortcutKey: "newTerminal") { editorVM.createTerminalTab(type: .terminal) }
                    Divider()
                    if isDatabaseEnabled {
                        menuItem("New SQL Query", shortcutKey: "newSQLQuery") { onNewSQLQuery() }
                        Divider()
                    }
                    menuItem("OpenCode", shortcutKey: "openOpenCode") { editorVM.createTerminalTab(type: .opencode) }
                    menuItem("Claude Code", shortcutKey: "openClaude") { editorVM.createTerminalTab(type: .claude) }
                    menuItem("Codex", shortcutKey: "openCodex") { editorVM.createTerminalTab(type: .codex) }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13))
                        .frame(width: 28, height: 36)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.textSecondary)
                .trackInteractiveFrame()

                GeometryReader { geometry in
                    let availableWidth = geometry.size.width
                    let tabWidth: CGFloat = 200
                    let maxVisibleTabs = max(1, Int(availableWidth / tabWidth))
                    let hasOverflow = allTabs.count > maxVisibleTabs

                    HStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(Array(editorVM.tabs.enumerated()), id: \.element.id) { index, tab in
                                    TabButton(
                                        tab: tab,
                                        index: index,
                                        isActive: tab.id == editorVM.activeTabId,
                                        allTabs: editorVM.tabs,
                                        onSelect: { editorVM.activateTab(tab.id) },
                                        onClose: { editorVM.closeTab(tab.id) },
                                        moveAction: { editorVM.moveTab(from: $0, to: $1) },
                                        draggedTabId: $draggedTabId,
                                        onMoveLeft: index > 0 ? { editorVM.moveTab(from: index, to: index - 1) } : nil,
                                        onMoveRight: index < editorVM.tabs.count - 1 ? { editorVM.moveTab(from: index, to: index + 1) } : nil
                                    )
                                    .trackInteractiveFrame()
                                }
                                ForEach(Array(terminalVM.tabs.enumerated()), id: \.element.id) { index, tab in
                                    TabButton(
                                        tab: tab,
                                        index: index,
                                        isActive: tab.id == editorVM.activeTabId,
                                        allTabs: terminalVM.tabs,
                                        onSelect: { editorVM.activateTab(tab.id) },
                                        onClose: { editorVM.closeTab(tab.id) },
                                        moveAction: { terminalVM.moveTab(from: $0, to: $1) },
                                        draggedTabId: $draggedTabId,
                                        onMoveLeft: index > 0 ? { terminalVM.moveTab(from: index, to: index - 1) } : nil,
                                        onMoveRight: index < terminalVM.tabs.count - 1 ? { terminalVM.moveTab(from: index, to: index + 1) } : nil
                                    )
                                    .trackInteractiveFrame()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            // If this is an internal tab drag, reject it so TabDropDelegate handles it.
                            if self.draggedTabId != nil {
                                return false
                            }
                            var foundItems: [String] = []
                            for provider in providers {
                                let sem = DispatchSemaphore(value: 0)
                                provider.loadObject(ofClass: NSString.self) { object, _ in
                                    if let text = object as? String {
                                        foundItems.append(text)
                                    }
                                    sem.signal()
                                }
                                sem.wait()
                            }
                            for text in foundItems {
                                editorVM.newFile(name: text, content: text)
                            }
                            return !foundItems.isEmpty
                        }

                        if hasOverflow {
                            TabOverflowMenu(
                                allTabs: allTabs,
                                activeTabId: editorVM.activeTabId,
                                onSelect: { editorVM.activateTab($0) },
                                onClose: { editorVM.closeTab($0) }
                            )
                            .trackInteractiveFrame()
                        }
                    }
                }

                HStack(spacing: 4) {
                    if editorVM.currentTab != nil && editorVM.currentTab?.type != .browser {
                        Button(action: {
                            splitVM.splitActivePane(.horizontal, editorVM: editorVM, terminalVM: terminalVM)
                        }) {
                            Image(systemName: "square.split.2x1")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.textSecondary)
                        .help("Split left/right")
                        .trackInteractiveFrame()

                        Button(action: {
                            splitVM.splitActivePane(.vertical, editorVM: editorVM, terminalVM: terminalVM)
                        }) {
                            Image(systemName: "square.split.1x2")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.textSecondary)
                        .help("Split top/bottom")
                        .trackInteractiveFrame()
                    }

                    if let onOpenBrowser {
                        Button(action: onOpenBrowser) {
                            Image(systemName: "globe")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.textSecondary)
                        .help("Open browser")
                        .trackInteractiveFrame()
                    }

                    Button(action: onToggleRightSidebar) {
                        Image(systemName: isRightSidebarExpanded ? "sidebar.right" : "sidebar.left")
                            .font(.system(size: 13))
                            .foregroundColor(isRightSidebarExpanded ? .textPrimary : .textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 8)
                    .trackInteractiveFrame()
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(height: 36)

            TitlebarBackgroundView(interactiveFrames: $interactiveFrames)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .coordinateSpace(name: "topbar")
        .onPreferenceChange(InteractiveFrameKey.self) { frames in
            interactiveFrames = frames
        }
        .frame(height: 36)
        .background(Color.bgPrimary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }

    private func toggleAllWorktrees() {
        let newValue = !allWorktreesExpanded
        for project in workspaceVM.projects {
            workspaceVM.setWorktreesExpanded(projectId: project.id, expanded: newValue)
        }
    }

    @ViewBuilder
    private func menuItem(_ label: String, shortcutKey: String, handler: @escaping () -> Void) -> some View {
        Button(action: handler) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                Spacer()
                if let shortcut = shortcutsService.shortcuts[shortcutKey], !shortcut.isEmpty {
                    Text(shortcut)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.textSecondary)
                }
            }
        }
    }
}

struct TabButton: View {
    let tab: Tab
    let index: Int
    let isActive: Bool
    let allTabs: [Tab]
    let onSelect: () -> Void
    let onClose: () -> Void
    let moveAction: (Int, Int) -> Void
    @Binding var draggedTabId: String?
    var onMoveLeft: (() -> Void)? = nil
    var onMoveRight: (() -> Void)? = nil
    @EnvironmentObject var appState: AppState

    @State private var isHovered = false

    var body: some View {
        ZStack {
            HStack(spacing: 6) {
                if tab.type == .browser {
                } else if tab.type == .file {
                    fileIcon(for: tab.name)
                        .foregroundColor(iconColor)
                        .font(.system(size: 13))
                } else if tab.type == .diff {
                    Image(systemName: "plus.forwardslash.minus")
                        .foregroundColor(iconColor)
                        .font(.system(size: 13))
                } else if tab.type == .queryResult {
                    Image(systemName: "tablecells")
                        .foregroundColor(iconColor)
                        .font(.system(size: 13))
                } else {
                    terminalIcon(for: tab.type)
                        .foregroundColor(iconColor)
                        .font(.system(size: 13))
                }

                Text(tab.isModified ? "\(tab.name) \u{25CF}" : tab.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .opacity(isHovered ? 0.6 : 0)
                    .onTapGesture { onClose() }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 28)
        .frame(height: 36)
        .background(
            isActive ? Color.bgActive :
            draggedTabId == tab.id ? Color.bgActive.opacity(0.5) : Color.clear
        )
        .foregroundColor(isActive ? .textPrimary : .textSecondary)
        .overlay(
            Rectangle().frame(height: 2).foregroundColor(isActive ? .accentBlue : .clear),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .onDrag {
            draggedTabId = tab.id
            return NSItemProvider(object: tab.id as NSString)
        }
        .onDrop(of: [.text], delegate: TabDropDelegate(
            tab: tab,
            index: index,
            allTabs: allTabs,
            draggedTabId: $draggedTabId,
            moveAction: moveAction
        ))
        .contextMenu {
            if tab.type == .browser {
                Button("Pin to Left Panel") {
                    appState.openURL(tab.url ?? "about:blank", in: .leftPanel)
                    onClose()
                }
                Button("Pin to Right Panel") {
                    appState.openURL(tab.url ?? "about:blank", in: .rightPanel)
                    onClose()
                }
                Divider()
            }
            Button("Close Tab") { onClose() }
            if onMoveLeft != nil {
                Button("Move Left") { onMoveLeft?() }
            }
            if onMoveRight != nil {
                Button("Move Right") { onMoveRight?() }
            }
        }
    }

    private var iconColor: Color {
        switch tab.type {
        case .terminal: return .accentGreen
        case .opencode: return .accentBlue
        case .claude: return .accentOrange
        case .codex: return .accentPurple
        case .diff: return .accentGreen
        case .file: return fileColor(for: tab.name)
        case .image: return .accentBlue
        case .pdf: return .accentRed
        case .queryResult: return .accentBlue
        case .browser: return .accentBlue
        case .restApi: return .accentGreen
        }
    }

    private func fileColor(for filename: String) -> Color {
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        switch ext {
        case "rs": return .fileRust
        case "ts", "tsx": return .fileTs
        case "js", "jsx": return .fileJs
        case "json": return .fileJson
        case "html", "htm": return .fileHtml
        case "css", "scss": return .fileCss
        case "md", "markdown": return .fileMd
        case "swift", "py", "go": return .accentBlue
        case "sh": return .accentGreen
        default: return .fileDefault
        }
    }

    private func fileIcon(for filename: String) -> Image {
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        switch ext {
        case "rs", "swift", "c", "cpp", "h", "java", "go", "py", "ts", "tsx", "js", "jsx":
            return Image(systemName: "curlybraces")
        case "json": return Image(systemName: "doc.text")
        case "html": return Image(systemName: "globe")
        case "css", "scss": return Image(systemName: "paintbrush")
        case "md": return Image(systemName: "text.alignleft")
        case "sh": return Image(systemName: "terminal")
        default: return Image(systemName: "doc")
        }
    }

    private func terminalIcon(for type: TabType) -> Image {
        switch type {
        case .terminal: return Image(systemName: "terminal")
        case .opencode: return Image(systemName: "command")
        case .claude: return Image(systemName: "circle")
        case .codex: return Image(systemName: "square.stack.3d.up")
        default: return Image(systemName: "terminal")
        }
    }
}

struct TabDropDelegate: DropDelegate {
    let tab: Tab
    let index: Int
    let allTabs: [Tab]
    @Binding var draggedTabId: String?
    let moveAction: (Int, Int) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { draggedTabId = nil }
        guard let draggedId = draggedTabId,
              let sourceIndex = allTabs.firstIndex(where: { $0.id == draggedId }),
              sourceIndex != index
        else { return false }

        let destinationIndex = index
        moveAction(sourceIndex, destinationIndex)
        return true
    }
}

struct TabOverflowMenu: View {
    let allTabs: [Tab]
    let activeTabId: String?
    let onSelect: (String) -> Void
    let onClose: (String) -> Void

    var body: some View {
        Menu {
            ForEach(allTabs, id: \.id) { tab in
                Button {
                    onSelect(tab.id)
                } label: {
                    HStack {
                        Text(tab.name)
                        Spacer()
                        if tab.id == activeTabId {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            ForEach(allTabs, id: \.id) { tab in
                Button(role: .destructive) {
                    onClose(tab.id)
                } label: {
                    Text("Close \(tab.name)")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13))
                .frame(width: 28, height: 36)
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(.textSecondary)
    }
}
