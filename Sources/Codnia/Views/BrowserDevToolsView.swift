import SwiftUI

struct BrowserDevToolsView: View {
    @ObservedObject var devToolsService: BrowserDevToolsService

    private var consoleErrorCount: Int {
        devToolsService.entries.filter { $0.level == .error }.count
    }

    private var consoleWarnCount: Int {
        devToolsService.entries.filter { $0.level == .warn }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            content
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(BrowserDevToolsService.DevToolsTab.allCases, id: \.self) { tab in
                        Button(action: {
                            devToolsService.selectedTab = tab
                            switch tab {
                            case .elements where devToolsService.domTree == nil:
                                devToolsService.refreshDOM()
                            case .styles where devToolsService.matchedStyles.isEmpty:
                                devToolsService.refreshStylesForSelected()
                            case .computed where devToolsService.computedStyle == nil:
                                devToolsService.refreshStylesForSelected()
                            case .storage where devToolsService.storageEntries.isEmpty:
                                devToolsService.refreshStorage()
                            case .sources where devToolsService.resources.isEmpty:
                                devToolsService.refreshSources()
                            case .application:
                                devToolsService.refreshApplication()
                            default:
                                break
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(tab.rawValue)
                                    .font(.system(size: 11))
                                if tab == .console {
                                    if consoleErrorCount > 0 {
                                        Text("\(consoleErrorCount)")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.accentRed)
                                            .cornerRadius(6)
                                    } else if consoleWarnCount > 0 {
                                        Text("\(consoleWarnCount)")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.accentYellow)
                                            .cornerRadius(6)
                                    }
                                }
                                if tab == .network && !devToolsService.networkEntries.isEmpty {
                                    Text("\(devToolsService.networkEntries.count)")
                                        .font(.system(size: 8))
                                        .foregroundColor(.textSecondary)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.bgTertiary)
                                        .cornerRadius(6)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundColor(devToolsService.selectedTab == tab ? .accentBlue : .textSecondary)
                            .background(devToolsService.selectedTab == tab ? Color.accentBlue.opacity(0.1) : Color.clear)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            Spacer()

            dockingMenu
        }
        .background(Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
    }

    private var dockingMenu: some View {
        Menu {
            ForEach(BrowserDevToolsService.DockingPosition.allCases, id: \.self) { pos in
                Button(action: { devToolsService.dockingPosition = pos }) {
                    HStack {
                        Text(pos.rawValue)
                        if devToolsService.dockingPosition == pos {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Button(action: { devToolsService.isFloating.toggle() }) {
                HStack {
                    Text(devToolsService.isFloating ? "Attach to window" : "Detach to window")
                    if devToolsService.isFloating {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Image(systemName: dockingIcon)
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
                .frame(width: 22, height: 22)
        }
        .help("Docking position")
        .padding(.trailing, 4)
    }

    private var dockingIcon: String {
        switch devToolsService.dockingPosition {
        case .bottom: return "rectangle.split.1x2"
        case .right:  return "rectangle.split.2x1"
        case .left:   return "rectangle.split.2x1"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch devToolsService.selectedTab {
        case .console:
            BrowserConsoleView(devToolsService: devToolsService)
        case .elements:
            BrowserElementsView(devToolsService: devToolsService)
        case .styles:
            BrowserStylesView(devToolsService: devToolsService)
        case .computed:
            BrowserComputedView(devToolsService: devToolsService)
        case .network:
            BrowserNetworkView(devToolsService: devToolsService)
        case .storage:
            BrowserStorageView(devToolsService: devToolsService)
        case .sources:
            BrowserSourcesView(devToolsService: devToolsService)
        case .application:
            BrowserApplicationView(devToolsService: devToolsService)
        }
    }
}
