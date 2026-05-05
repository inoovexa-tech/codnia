import SwiftUI

struct TabBarView: View {
    @ObservedObject var editorVM: EditorViewModel
    @ObservedObject var terminalVM: TerminalViewModel

    var onToggleRightSidebar: () -> Void
    var onToggleSearch: () -> Void
    var isRightSidebarExpanded: Bool
    var isSearchActive: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Plus button
            Button(action: {
                editorVM.newFile()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 13))
                    .frame(width: 28, height: 38)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textSecondary)

            // Tab list
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(editorVM.tabs.enumerated()), id: \.offset) { index, tab in
                        TabButton(
                            tab: tab,
                            isActive: tab.id == editorVM.activeTabId,
                            onSelect: { editorVM.activateTab(tab.id) },
                            onClose: { editorVM.closeTab(tab.id) }
                        )
                    }
                    ForEach(Array(terminalVM.tabs.enumerated()), id: \.offset) { index, tab in
                        TabButton(
                            tab: tab,
                            isActive: tab.id == editorVM.activeTabId,
                            onSelect: { editorVM.activeTabId = tab.id },
                            onClose: { editorVM.closeTab(tab.id) }
                        )
                    }
                }
            }

            // Right buttons
            HStack(spacing: 4) {
                Button(action: onToggleSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .frame(width: 28, height: 38)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(isSearchActive ? .accentBlue : .textSecondary)

                Button(action: onToggleRightSidebar) {
                    Image(systemName: isRightSidebarExpanded ? "sidebar.right" : "sidebar.left")
                        .font(.system(size: 13))
                        .frame(width: 28, height: 38)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(isRightSidebarExpanded ? .accentBlue : .textSecondary)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 38)
    }
}

struct TabButton: View {
    let tab: Tab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    private var displayName: String {
        tab.isModified ? "\(tab.name) ●" : tab.name
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
        case "swift": return .accentBlue
        case "py": return .accentBlue
        case "go": return .accentBlue
        case "sh": return .accentGreen
        default: return .fileDefault
        }
    }

    var body: some View {
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

            Text(displayName)
                .font(.system(size: 12))
                .lineLimit(1)

            // Xmark como Text/Image clicável em vez de Button aninhado
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textSecondary)
                .opacity(isHovered ? 0.6 : 0)
                .onTapGesture {
                    onClose()
                }
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(isActive ? Color.bgActive : Color.clear)
        .foregroundColor(isActive ? .textPrimary : .textSecondary)
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundColor(isActive ? .accentBlue : .clear),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func fileIcon(for filename: String) -> Image {
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        switch ext {
        case "rs", "swift", "c", "cpp", "h", "java", "go", "py", "ts", "tsx", "js", "jsx":
            return Image(systemName: "curlybraces")
        case "json":
            return Image(systemName: "doc.text")
        case "html":
            return Image(systemName: "globe")
        case "css", "scss":
            return Image(systemName: "paintbrush")
        case "md":
            return Image(systemName: "text.alignleft")
        case "sh":
            return Image(systemName: "terminal")
        default:
            return Image(systemName: "doc")
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
