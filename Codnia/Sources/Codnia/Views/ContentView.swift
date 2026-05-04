import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    @State private var leftSidebarExpanded = false
    @State private var rightSidebarExpanded = false
    @State private var rightSidebarTab: RightSidebarTab = .explorer
    @State private var activityBarWidth: CGFloat = 320
    @State private var leftSidebarWidth: CGFloat = 220

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Title Bar / Tab Bar
            TabBarView()
                .frame(height: 34)
                .background(Color.bgPrimary)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.borderDefault),
                    alignment: .bottom
                )
                .environmentObject(appState.editorVM)
                .environmentObject(appState.terminalVM)
                .environmentObject(appState.settings)
                .environmentObject(appState.workspaceVM)

            // MARK: Main Area
            HStack(spacing: 0) {
                // Left Sidebar (Projects)
                SidebarView(
                    expanded: $leftSidebarExpanded
                )
                .frame(width: leftSidebarExpanded ? leftSidebarWidth : 52)
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
                if rightSidebarExpanded {
                    ActivityBarView(
                        tab: $rightSidebarTab,
                        width: $activityBarWidth
                    )
                    .frame(width: activityBarWidth)
                    .background(Color.bgSecondary)
                    .overlay(
                        ResizableDivider(width: $activityBarWidth, min: 200, max: 600),
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

enum RightSidebarTab: String, CaseIterable {
    case explorer = "Explorer"
    case search = "Search"
}

struct ResizableDivider: View {
    @Binding var width: CGFloat
    let min: CGFloat
    let max: CGFloat
    @State private var dragging = false

    var body: some View {
        Rectangle()
            .frame(width: 4)
            .foregroundColor(dragging ? Color.accentBlue : Color.clear)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragging = true
                        let newWidth = width - value.translation.width
                        width = min(max(newWidth, min), max)
                    }
                    .onEnded { _ in
                        dragging = false
                    }
            )
            .cursor(.resizeLeftRight)
    }
}
