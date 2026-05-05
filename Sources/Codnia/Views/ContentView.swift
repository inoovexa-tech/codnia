import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Title Bar / Tab Bar
            TabBarView(
                editorVM: appState.editorVM,
                terminalVM: appState.terminalVM,
                onToggleRightSidebar: {
                    appState.rightSidebarExpanded.toggle()
                },
                onToggleSearch: {
                    if appState.rightSidebarExpanded && appState.rightSidebarTab == .search {
                        appState.rightSidebarExpanded = false
                        appState.editorVM.showGlobalSearch = false
                    } else {
                        appState.rightSidebarTab = .search
                        appState.rightSidebarExpanded = true
                        appState.editorVM.showGlobalSearch = true
                    }
                },
                isRightSidebarExpanded: appState.rightSidebarExpanded,
                isSearchActive: appState.rightSidebarExpanded && appState.rightSidebarTab == .search
            )
            .frame(height: 28)
            .background(Color.bgPrimary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.borderDefault),
                alignment: .bottom
            )

            // MARK: Main Area
            HStack(spacing: 0) {
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
                .environmentObject(appState)
                .environmentObject(appState.workspaceVM)
                .environmentObject(appState.editorVM)
                .environmentObject(appState.settings)

                EditorAreaView()
                    .background(Color.bgPrimary)
                    .environmentObject(appState.editorVM)
                    .environmentObject(appState.terminalVM)
                    .environmentObject(appState.settings)

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