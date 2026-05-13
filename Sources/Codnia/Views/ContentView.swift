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
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            TabBarView(
                editorVM: appState.editorVM,
                terminalVM: appState.terminalVM,
                workspaceVM: appState.workspaceVM,
                settings: appState.settings,
                onToggleRightSidebar: { appState.rightSidebarExpanded.toggle() },
                isRightSidebarExpanded: appState.rightSidebarExpanded
            )
            .frame(height: 36)
        }
        .background(Color.bgPrimary)
        .edgesIgnoringSafeArea(.top)
        .overlay(
            Group {
                if appState.showGlobalSearchModal {
                    GlobalSearchModalView(isPresented: $appState.showGlobalSearchModal)
                        .environmentObject(appState.searchVM)
                        .environmentObject(appState.workspaceVM)
                        .environmentObject(appState.editorVM)
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
