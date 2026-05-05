import SwiftUI

struct ActivityBarView: View {
    @Binding var tab: RightSidebarTab
    @Binding var width: CGFloat
    @EnvironmentObject var workspaceVM: WorkspaceService
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var searchVM: SearchService

    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs
            HStack(spacing: 2) {
                Button(action: { tab = .explorer }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 13))
                        Text("Explorer")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(tab == .explorer ? Color(bgHex: "#1c1c1c") : Color.clear)
                    .foregroundColor(tab == .explorer ? .textPrimary : .textTertiary)
                    .cornerRadius(5)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { tab = .search }) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                        Text("Search")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(tab == .search ? Color(bgHex: "#1c1c1c") : Color.clear)
                    .foregroundColor(tab == .search ? .textPrimary : .textTertiary)
                    .cornerRadius(5)
                }
                .buttonStyle(PlainButtonStyle())

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

            // Content
            if tab == .explorer {
                FileTreeView(
                    entries: workspaceVM.fileTree,
                    onSelect: { path in
                        editorVM.openFile(path)
                    }
                )
                .background(Color.bgPrimary)
            } else {
                GlobalSearchView()
                    .environmentObject(searchVM)
                    .environmentObject(workspaceVM)
                    .environmentObject(editorVM)
                    .background(Color.bgPrimary)
            }
        }
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(.borderDefault),
            alignment: .leading
        )
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

// Temporary bridge for Color init
private extension Color {
    init(bgHex: String) {
        self = Color(hex: bgHex)
    }
}
