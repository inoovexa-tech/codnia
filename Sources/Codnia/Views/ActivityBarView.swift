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

            HStack(spacing: 2) {
                if tab == .explorer {
                    Button(action: {
                        workspaceVM.refreshFileTree()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(PlainActivityButton())
                }
            }
        }
        .frame(height: 42)
        .padding(.horizontal, 8)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(bgHex: "#1c1c1c")),
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
        .background(isActive ? Color(bgHex: "#1c1c1c") : Color.clear)
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
                }
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
            .frame(width: 28, height: 28)
            .background(configuration.isPressed ? Color(bgHex: "#1c1c1c") : Color.clear)
            .cornerRadius(4)
    }
}

private extension Color {
    init(bgHex: String) {
        self = Color(hex: bgHex)
    }
}
