import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsService
    @EnvironmentObject var themeManager: ThemeManager

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

                    SplitEditorView()
                        .background(Color.bgPrimary)
                        .environmentObject(appState)
                        .environmentObject(appState.splitVM)
                        .environmentObject(appState.editorVM)
                        .environmentObject(appState.terminalVM)
                        .environmentObject(settings)
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
                        .environmentObject(appState.notesVM)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            TabBarView(
                editorVM: appState.editorVM,
                terminalVM: appState.terminalVM,
                splitVM: appState.splitVM,
                workspaceVM: appState.workspaceVM,
                settings: appState.settings,
                onToggleRightSidebar: { appState.rightSidebarExpanded.toggle() },
                isRightSidebarExpanded: appState.rightSidebarExpanded,
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
            )
            .frame(height: 36)
        }
        .background(Color.bgPrimary)
        .id(themeManager.theme.id)
        .edgesIgnoringSafeArea(.top)
        .overlay(
            Group {
                if appState.showGlobalSearchModal {
                    GlobalSearchModalView(isPresented: $appState.showGlobalSearchModal)
                        .environmentObject(appState.searchVM)
                        .environmentObject(appState.workspaceVM)
                        .environmentObject(appState.editorVM)
                }

                if appState.showAddProjectModal {
                    AddProjectModalView(
                        isPresented: $appState.showAddProjectModal,
                        onSelect: { path in
                            appState.workspaceVM.addProject(path: path)
                        }
                    )
                }
            }
        )
        .onAppear {
            if appState.workspaceVM.projects.isEmpty {
                appState.workspaceVM.loadProjects()
            }
        }
    }


}