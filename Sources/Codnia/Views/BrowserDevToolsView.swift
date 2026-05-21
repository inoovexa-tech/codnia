import SwiftUI

struct BrowserDevToolsView: View {
    @ObservedObject var devToolsService: BrowserDevToolsService

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            content
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(BrowserDevToolsService.DevToolsTab.allCases, id: \.self) { tab in
                    Button(action: {
                        devToolsService.selectedTab = tab
                        if tab == .elements && devToolsService.domTree == nil {
                            devToolsService.refreshDOM()
                        }
                        if tab == .storage && devToolsService.storageEntries.isEmpty {
                            devToolsService.refreshStorage()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.system(size: 11))
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
        .background(Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
    }

    @ViewBuilder
    private var content: some View {
        switch devToolsService.selectedTab {
        case .console:
            BrowserConsoleView(devToolsService: devToolsService)
        case .elements:
            BrowserElementsView(devToolsService: devToolsService)
        case .network:
            BrowserNetworkView(devToolsService: devToolsService)
        case .storage:
            BrowserStorageView(devToolsService: devToolsService)
        }
    }
}
