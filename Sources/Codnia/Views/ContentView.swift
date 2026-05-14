import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 36)
                    .allowsHitTesting(false)

                HStack(spacing: 0) {
                    SidebarView(expanded: $settings.leftSidebarExpanded)
                        .frame(width: settings.leftSidebarExpanded ? settings.leftSidebarWidth : 52)
                        .background(Color.bgPrimary)
                        .overlay(Rectangle().frame(width: 1).foregroundColor(.borderDefault), alignment: .trailing)
                        .environmentObject(appState)
                        .environmentObject(appState.workspaceVM)
                        .environmentObject(appState.editorVM)
                        .environmentObject(appState.terminalVM)
                        .environmentObject(appState.gitVM)
                        .environmentObject(settings)

                    EditorAreaView()
                        .background(Color.bgPrimary)
                        .environmentObject(appState.editorVM)
                        .environmentObject(appState.terminalVM)
                        .environmentObject(settings)
                        .environmentObject(appState.databaseService)

                    if appState.rightSidebarExpanded {
                        ResizableDivider(
                            width: $settings.activityBarWidth,
                            minWidth: 320,
                            maxWidth: 600,
                            side: .right
                        )
                        .frame(width: 6)
                        .zIndex(10)

                        ActivityBarView(
                            tab: $appState.rightSidebarTab,
                            width: $settings.activityBarWidth
                        )
                        .frame(width: settings.activityBarWidth)
                        .background(Color.bgSecondary)
                        .environmentObject(appState.workspaceVM)
                        .environmentObject(appState.editorVM)
                        .environmentObject(appState.searchVM)
                        .environmentObject(appState.gitVM)
                        .environmentObject(appState.tasksVM)
                        .environmentObject(appState.pluginService)
                        .environmentObject(appState.databaseService)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            TabBarView(
                editorVM: appState.editorVM,
                terminalVM: appState.terminalVM,
                onToggleExplorer: {
                    if appState.rightSidebarExpanded && appState.rightSidebarTab == .explorer {
                        appState.rightSidebarExpanded = false
                    } else {
                        appState.rightSidebarTab = .explorer
                        appState.rightSidebarExpanded = true
                    }
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
                onToggleSourceControl: {
                    if appState.rightSidebarExpanded && appState.rightSidebarTab == .sourceControl {
                        appState.rightSidebarExpanded = false
                    } else {
                        appState.rightSidebarTab = .sourceControl
                        appState.rightSidebarExpanded = true
                    }
                },
                onToggleTasks: {
                    let tasksId = "tasks"
                    if appState.rightSidebarExpanded && appState.rightSidebarTab == .plugin(tasksId) {
                        appState.rightSidebarExpanded = false
                    } else {
                        appState.rightSidebarTab = .plugin(tasksId)
                        appState.rightSidebarExpanded = true
                    }
                },
                onToggleRightSidebar: { appState.rightSidebarExpanded.toggle() },
                isRightSidebarExpanded: appState.rightSidebarExpanded,
                isExplorerActive: appState.rightSidebarExpanded && appState.rightSidebarTab == .explorer,
                isSearchActive: appState.rightSidebarExpanded && appState.rightSidebarTab == .search,
                isSourceControlActive: appState.rightSidebarExpanded && appState.rightSidebarTab == .sourceControl,
                isTasksActive: appState.rightSidebarExpanded && appState.rightSidebarTab == .plugin("tasks"),
                isTasksEnabled: appState.pluginService.isActive(pluginId: "tasks"),
                isDatabaseEnabled: appState.databaseService.hasConnections,
                onNewSQLQuery: {
                    let connId = appState.databaseService.connections.first?.id
                    appState.editorVM.newQueryTab(connectionId: connId)
                }
            )
            .frame(height: 36)
        }
        .background(Color.bgPrimary)
        .edgesIgnoringSafeArea(.top)
        .onAppear {
            if appState.workspaceVM.projects.isEmpty {
                appState.workspaceVM.loadProjects()
            }
        }
    }
}
