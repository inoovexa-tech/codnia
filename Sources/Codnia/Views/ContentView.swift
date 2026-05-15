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

                    if appState.leftBrowserExpanded {
                        BrowserView(
                            tabId: "left-panel",
                            urlString: $appState.leftBrowserURL,
                            pageTitle: $appState.leftBrowserTitle,
                            onNavigate: { appState.leftBrowserURL = $0 },
                            onClose: { appState.leftBrowserExpanded = false },
                            onPinToLeft: { appState.leftBrowserExpanded = false },
                            onPinToRight: {
                                appState.rightBrowserURL = appState.leftBrowserURL
                                appState.rightBrowserExpanded = true
                                appState.leftBrowserExpanded = false
                            },
                            onPinToTab: {
                                appState.openURL(appState.leftBrowserURL, in: .tab)
                                appState.leftBrowserExpanded = false
                            }
                        )
                        .frame(width: settings.leftBrowserWidth)
                        .background(Color.bgSecondary)

                        ResizableDivider(
                            width: $settings.leftBrowserWidth,
                            minWidth: 250,
                            maxWidth: 1200,
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

                    if appState.rightBrowserExpanded {
                        ResizableDivider(
                            width: $settings.rightBrowserWidth,
                            minWidth: 250,
                            maxWidth: 1200,
                            side: .right
                        )
                        .frame(width: 8)
                        .background(Color.borderDefault.opacity(0.15))
                        .zIndex(10)

                        BrowserView(
                            tabId: "right-panel",
                            urlString: $appState.rightBrowserURL,
                            pageTitle: $appState.rightBrowserTitle,
                            onNavigate: { appState.rightBrowserURL = $0 },
                            onClose: { appState.rightBrowserExpanded = false },
                            onPinToLeft: {
                                appState.leftBrowserURL = appState.rightBrowserURL
                                appState.leftBrowserExpanded = true
                                appState.rightBrowserExpanded = false
                            },
                            onPinToRight: { appState.rightBrowserExpanded = false },
                            onPinToTab: {
                                appState.openURL(appState.rightBrowserURL, in: .tab)
                                appState.rightBrowserExpanded = false
                            }
                        )
                        .frame(width: settings.rightBrowserWidth)
                        .background(Color.bgSecondary)
                    }

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