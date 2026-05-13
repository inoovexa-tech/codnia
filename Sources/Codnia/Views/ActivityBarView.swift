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

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 2) {
            Button(action: { tab = .explorer }) {
                tabButtonLabel(icon: "folder", label: "Explorer", isActive: tab == .explorer)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { tab = .search }) {
                tabButtonLabel(icon: "magnifyingglass", label: "Search", isActive: tab == .search)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { tab = .sourceControl }) {
                tabButtonLabel(icon: "arrow.triangle.branch", label: "Git", isActive: tab == .sourceControl)
            }
            .buttonStyle(PlainButtonStyle())

            ForEach(Array(pluginService.activeSidebarPlugins), id: \.id) { plugin in
                Button(action: { tab = .plugin(plugin.id) }) {
                    tabButtonLabel(
                        icon: plugin.iconName,
                        label: plugin.name,
                        isActive: tab == .plugin(plugin.id)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()

            if tab == .explorer {
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
        }
        .frame(height: 42)
        .padding(.horizontal, 8)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#1c1c1c")),
            alignment: .bottom
        )
    }

    private func tabButtonLabel(icon: String, label: String, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
            Text(label)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isActive ? Color(hex: "#1c1c1c") : Color.clear)
        .foregroundColor(isActive ? .textPrimary : .textTertiary)
        .cornerRadius(5)
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
