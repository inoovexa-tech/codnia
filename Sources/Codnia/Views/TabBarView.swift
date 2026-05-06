import SwiftUI

struct TabBarView: View {
    @ObservedObject var editorVM: EditorViewModel
    @ObservedObject var terminalVM: TerminalViewModel

    var onToggleRightSidebar: () -> Void
    var onToggleSearch: () -> Void
    var isRightSidebarExpanded: Bool
    var isSearchActive: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Spacer().frame(width: 90)

                Menu {
                    Button("New File") { editorVM.newFile() }
                        .keyboardShortcut("n", modifiers: .command)
                    Button("New Terminal") { editorVM.createTerminalTab(type: .terminal) }
                        .keyboardShortcut("t", modifiers: .command)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13))
                        .frame(width: 28, height: 36)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(editorVM.tabs.enumerated()), id: \.element.id) { index, tab in
                            TabButton(
                                tab: tab,
                                isActive: tab.id == editorVM.activeTabId,
                                onSelect: { editorVM.activateTab(tab.id) },
                                onClose: { editorVM.closeTab(tab.id) },
                                onMoveLeft: index > 0 ? { editorVM.moveTab(from: index, to: index - 1) } : nil,
                                onMoveRight: index < editorVM.tabs.count - 1 ? { editorVM.moveTab(from: index, to: index + 1) } : nil
                            )
                        }
                        ForEach(Array(terminalVM.tabs.enumerated()), id: \.element.id) { index, tab in
                            TabButton(
                                tab: tab,
                                isActive: tab.id == editorVM.activeTabId,
                                onSelect: { editorVM.activeTabId = tab.id },
                                onClose: { editorVM.closeTab(tab.id) },
                                onMoveLeft: index > 0 ? { terminalVM.moveTab(from: index, to: index - 1) } : nil,
                                onMoveRight: index < terminalVM.tabs.count - 1 ? { terminalVM.moveTab(from: index, to: index + 1) } : nil
                            )
                        }
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Button(action: onToggleSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(isSearchActive ? .accentBlue : .textSecondary)

                    Button(action: onToggleRightSidebar) {
                        Image(systemName: isRightSidebarExpanded ? "sidebar.right" : "sidebar.left")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(isRightSidebarExpanded ? .accentBlue : .textSecondary)
                }
                .padding(.horizontal, 8)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 36)
        .background(Color.bgPrimary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }
}

struct TabButton: View {
    let tab: Tab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    var onMoveLeft: (() -> Void)? = nil
    var onMoveRight: (() -> Void)? = nil

    @State private var isHovered = false

    var body: some View {
        ZStack {
            HStack(spacing: 6) {
                if tab.type == .file {
                    fileIcon(for: tab.name)
                        .foregroundColor(iconColor)
                        .font(.system(size: 13))
                } else {
                    terminalIcon(for: tab.type)
                        .foregroundColor(iconColor)
                        .font(.system(size: 13))
                }

                Text(tab.isModified ? "\(tab.name) ●" : tab.name)
                    .font(.system(size: 12))
                    .lineLimit(1)

                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .opacity(isHovered ? 0.6 : 0)
                    .onTapGesture { onClose() }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(isActive ? Color.bgActive : Color.clear)
        .foregroundColor(isActive ? .textPrimary : .textSecondary)
        .overlay(
            Rectangle().frame(height: 2).foregroundColor(isActive ? .accentBlue : .clear),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .contextMenu {
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
        case .file: return fileColor(for: tab.name)
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