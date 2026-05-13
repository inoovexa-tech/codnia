import SwiftUI

struct ActivityBarView: View {
    @Binding var tab: RightSidebarTab
    @Binding var width: CGFloat
    @EnvironmentObject var workspaceVM: WorkspaceService
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var searchVM: SearchService
    @EnvironmentObject var gitVM: GitViewModel
    @EnvironmentObject var tasksVM: TasksViewModel
    @EnvironmentObject var pluginService: PluginService

    @State private var selectedPath: String? = nil
    @State private var headerAction: FileTreeHeaderAction? = nil

    var body: some View {
        VStack(spacing: 0) {
            topTabBar
            header
            content
        }
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(.borderDefault),
            alignment: .leading
        )
        .onChange(of: editorVM.activeTabId) { _ in
            syncSelectionWithEditor()
        }
    }

    private func syncSelectionWithEditor() {
        guard let tab = editorVM.currentTab else {
            if tab != .search && tab != .sourceControl {
                selectedPath = nil
            }
            return
        }
        guard tab.type == .file || tab.type == .image || tab.type == .pdf else { return }
        selectedPath = tab.path
    }

    // MARK: - Top Tab Bar

    private var topTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(tabItems.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(.borderDefault)
                    }

                    Button(action: { tab = item.tab }) {
                        Image(systemName: item.icon)
                            .font(.system(size: 13))
                            .foregroundColor(tab == item.tab ? .textPrimary : .textTertiary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(item.title)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 36)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }

    private struct TabItem: Identifiable {
        let id: String
        let icon: String
        let title: String
        let tab: RightSidebarTab
    }

    private var tabItems: [TabItem] {
        var items: [TabItem] = [
            TabItem(id: "explorer", icon: "folder", title: "Explorer", tab: .explorer),
            TabItem(id: "search", icon: "magnifyingglass", title: "Search", tab: .search),
            TabItem(id: "sourceControl", icon: "arrow.triangle.branch", title: "Source Control", tab: .sourceControl),
        ]
        for plugin in pluginService.activeSidebarPlugins {
            items.append(TabItem(id: plugin.id, icon: plugin.iconName, title: plugin.name, tab: .plugin(plugin.id)))
        }
        return items
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: currentTabIcon)
                    .font(.system(size: 13))
                    .foregroundColor(.textPrimary)
                Text(currentTabTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            if tab == .explorer {
                explorerActions
            }
        }
        .frame(height: 36)
        .padding(.horizontal, 12)
        .background(Color.bgPrimary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }

    private var currentTabIcon: String {
        switch tab {
        case .explorer: return "folder"
        case .search: return "magnifyingglass"
        case .sourceControl: return "arrow.triangle.branch"
        case .plugin(let id):
            return pluginService.plugin(withId: id)?.iconName ?? "puzzlepiece"
        }
    }

    private var currentTabTitle: String {
        switch tab {
        case .explorer: return "Explorer"
        case .search: return "Search"
        case .sourceControl: return "Source Control"
        case .plugin(let id):
            return pluginService.plugin(withId: id)?.name ?? "Plugin"
        }
    }

    private var explorerActions: some View {
        HStack(spacing: 2) {
            Button(action: { headerAction = .newFile }) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 12))
            }
            .buttonStyle(PlainActivityButton())
            .help("New File")

            Button(action: { headerAction = .newFolder }) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 12))
            }
            .buttonStyle(PlainActivityButton())
            .help("New Folder")

            Button(action: { headerAction = .collapseAll }) {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11))
            }
            .buttonStyle(PlainActivityButton())
            .help("Collapse All")

            Button(action: {
                workspaceVM.refreshFileTree()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(PlainActivityButton())
            .help("Refresh")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .explorer:
            FileTreeView(
                entries: workspaceVM.fileTree,
                onSelect: { path in
                    editorVM.openFile(path)
                },
                onRefresh: {
                    workspaceVM.refreshFileTree()
                },
                selectedPath: $selectedPath,
                activeFilePath: editorVM.currentTab?.path,
                rootPath: workspaceVM.activeProject?.activeWorktree?.path ?? "",
                modifiedPaths: editorVM.modifiedFilePaths,
                headerAction: $headerAction
            )
            .background(Color.bgPrimary)
            .frame(maxHeight: .infinity)

        case .search:
            GlobalSearchView()
                .environmentObject(searchVM)
                .environmentObject(workspaceVM)
                .environmentObject(editorVM)
                .background(Color.bgPrimary)

        case .sourceControl:
            SourceControlView()
                .environmentObject(gitVM)
                .environmentObject(workspaceVM)
                .background(Color.bgPrimary)

        case .plugin(let id):
            if let plugin = pluginService.plugin(withId: id) {
                plugin.makeView()
                    .environmentObject(tasksVM)
                    .environmentObject(workspaceVM)
                    .environmentObject(pluginService)
                    .background(Color.bgPrimary)
                    .frame(maxHeight: .infinity)
            } else {
                VStack {
                    Text("Plugin not found")
                        .font(.system(size: 13))
                        .foregroundColor(.textTertiary)
                    Text("ID: \(id)")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                }
                .frame(maxHeight: .infinity)
                .background(Color.bgPrimary)
            }
        }
    }
}

struct PlainActivityButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.textTertiary)
            .frame(width: 26, height: 26)
            .background(configuration.isPressed ? Color(hex: "#1c1c1c") : Color.clear)
            .cornerRadius(4)
    }
}
