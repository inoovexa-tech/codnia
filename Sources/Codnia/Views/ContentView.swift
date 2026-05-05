import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Title Bar / Tab Bar — same row as traffic lights
            TabBarView()
                .frame(height: 28)
                .padding(.leading, 70) // traffic lights width
                .padding(.top, 0)
                .background(Color.bgPrimary)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.borderDefault),
                    alignment: .bottom
                )
                .environmentObject(appState)

            // MARK: Main Area
            HStack(spacing: 0) {
                // Left Sidebar (Projects)
                SidebarView(
                    expanded: $appState.leftSidebarExpanded
                )
                .frame(width: appState.leftSidebarExpanded ? appState.leftSidebarWidth : 52)
                .background(Color.bgPrimary)
                .overlay(
                    Rectangle()
                        .frame(width: 1)
                        .foregroundColor(.borderDefault),
                    alignment: .trailing
                )
                .environmentObject(appState.workspaceVM)
                .environmentObject(appState.editorVM)
                .environmentObject(appState.settings)

                // Editor / Terminal Area
                EditorAreaView()
                    .background(Color.bgPrimary)
                    .environmentObject(appState.editorVM)
                    .environmentObject(appState.terminalVM)
                    .environmentObject(appState.settings)

                // Right Sidebar (Activity Bar: Explorer + Search)
                if appState.rightSidebarExpanded {
                    ActivityBarView(
                        tab: $appState.rightSidebarTab,
                        width: $appState.activityBarWidth
                    )
                    .frame(width: appState.activityBarWidth)
                    .background(Color.bgSecondary)
                    .overlay(
                        ResizableDivider(width: $appState.activityBarWidth, minWidth: 200, maxWidth: 600),
                        alignment: .leading
                    )
                    .environmentObject(appState.workspaceVM)
                    .environmentObject(appState.editorVM)
                    .environmentObject(appState.searchVM)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // MARK: Status Bar
            if shouldShowStatusBar {
                StatusBarView()
                    .frame(height: 22)
                    .background(Color.bgPrimary)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.borderDefault),
                        alignment: .top
                    )
                    .environmentObject(appState.editorVM)
                    .environmentObject(appState.workspaceVM)
            }
        }
        .background(Color.bgPrimary)
        .onAppear {
            appState.workspaceVM.loadProjects()
        }
    }

    private var shouldShowStatusBar: Bool {
        guard let tab = appState.editorVM.currentTab else { return false }
        return tab.type == .file
    }
}
