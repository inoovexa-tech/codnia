import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        ZStack(alignment: .top) {
            // Conteúdo principal (começa abaixo da tab bar)
            VStack(spacing: 0) {
                // Espaçador para a área da tab bar (36pt)
                Color.clear
                    .frame(height: 36)
                    .allowsHitTesting(false)

                // Main area
                HStack(spacing: 0) {
                    SidebarView(expanded: $appState.leftSidebarExpanded)
                        .frame(width: appState.leftSidebarExpanded ? settings.leftSidebarWidth : 52)
                        .background(Color.bgPrimary)
                        .overlay(Rectangle().frame(width: 1).foregroundColor(.borderDefault), alignment: .trailing)
                        .environmentObject(appState)
                        .environmentObject(appState.workspaceVM)
                        .environmentObject(appState.editorVM)
                        .environmentObject(appState.terminalVM)
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
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // StatusBarView removed as per user request
            }

            // Tab bar sobreposta no topo absoluto da janela
            TabBarView(
                editorVM: appState.editorVM,
                terminalVM: appState.terminalVM,
                onToggleRightSidebar: { appState.rightSidebarExpanded.toggle() },
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
                isRightSidebarExpanded: appState.rightSidebarExpanded,
                isSearchActive: appState.rightSidebarExpanded && appState.rightSidebarTab == .search,
                isSourceControlActive: appState.rightSidebarExpanded && appState.rightSidebarTab == .sourceControl
            )
            .frame(height: 36)
        }
        .background(Color.bgPrimary)
        .edgesIgnoringSafeArea(.top)
        .onAppear { appState.workspaceVM.loadProjects() }
    }
}
