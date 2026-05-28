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
                    if !appState.isZenMode {
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
                    }

                    if !appState.isZenMode && appState.browserExpanded && appState.browserSide == .left {
                        BrowserView(
                            tabId: "browser-panel",
                            urlString: $appState.browserURL,
                            pageTitle: $appState.browserTitle,
                            onNavigate: { appState.browserURL = $0 },
                            onClose: { appState.closeBrowser() },
                            onPinToLeft: { appState.closeBrowser() },
                            onPinToRight: { appState.browserSide = .right },
                            onPinToTab: {
                                appState.openURL(appState.browserURL, in: .tab)
                                appState.closeBrowser()
                            }
                        )
                        .frame(width: appState.browserWidth)
                        .background(Color.bgSecondary)

                        ResizableDivider(
                            width: $appState.browserWidth,
                            minWidth: 250,
                            maxWidth: 1800,
                            side: .left
                        )
                        .frame(width: 8)
                        .background(Color.borderDefault.opacity(0.15))
                        .zIndex(10)
                    }

                    SplitEditorView()
                        .background(Color.bgPrimary)
                        .environmentObject(appState)
                        .environmentObject(appState.splitVM)
                        .environmentObject(appState.editorVM)
                        .environmentObject(appState.terminalVM)
                        .environmentObject(settings)
                        .environmentObject(appState.databaseService)

                    if !appState.isZenMode && appState.browserExpanded && appState.browserSide == .right {
                        ResizableDivider(
                            width: $appState.browserWidth,
                            minWidth: 250,
                            maxWidth: 1800,
                            side: .right
                        )
                        .frame(width: 8)
                        .background(Color.borderDefault.opacity(0.15))
                        .zIndex(10)

                        BrowserView(
                            tabId: "browser-panel",
                            urlString: $appState.browserURL,
                            pageTitle: $appState.browserTitle,
                            onNavigate: { appState.browserURL = $0 },
                            onClose: { appState.closeBrowser() },
                            onPinToLeft: { appState.browserSide = .left },
                            onPinToRight: { appState.closeBrowser() },
                            onPinToTab: {
                                appState.openURL(appState.browserURL, in: .tab)
                                appState.closeBrowser()
                            }
                        )
                        .frame(width: appState.browserWidth)
                        .background(Color.bgSecondary)
                    }

                    if !appState.isZenMode && appState.rightSidebarExpanded {
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
                        .environmentObject(appState.notesVM)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !appState.isZenMode {
                    StatusBarView()
                        .frame(height: 24)
                        .background(Color.bgSecondary)
                        .environmentObject(appState.editorVM)
                        .environmentObject(appState.workspaceVM)
                        .environmentObject(appState.settings)
                }
            }

            TabBarView(
                editorVM: appState.editorVM,
                terminalVM: appState.terminalVM,
                splitVM: appState.splitVM,
                workspaceVM: appState.workspaceVM,
                settings: appState.settings,
                onToggleRightSidebar: { appState.rightSidebarExpanded.toggle() },
                isRightSidebarExpanded: appState.rightSidebarExpanded,
                isDatabaseEnabled: appState.databaseService.hasConnections,
                onNewSQLQuery: {
                    let connId = appState.databaseService.connections.first?.id
                    appState.editorVM.newQueryTab(connectionId: connId)
                },
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
                onOpenBrowser: {
                    let url = appState.settings.browserDefaultURL.isEmpty ? "about:blank" : appState.settings.browserDefaultURL
                    let location = BrowserOpenIn(rawValue: appState.settings.browserDefaultLocation) ?? .tab
                    appState.openURL(url, in: location)
                }
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