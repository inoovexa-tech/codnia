import SwiftUI

struct BrowserSidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: BrowserSidebarTab = .history

    enum BrowserSidebarTab: String, CaseIterable, Identifiable {
        case history = "History"
        case downloads = "Downloads"
        case credentials = "Logins"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .history: return "clock.arrow.circlepath"
            case .downloads: return "arrow.down.circle"
            case .credentials: return "key"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            switch selectedTab {
            case .history:
                BrowserHistoryView()
            case .downloads:
                BrowserDownloadsView()
            case .credentials:
                BrowserCredentialsView()
            }
        }
        .background(Color.bgPrimary)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(BrowserSidebarTab.allCases) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11))
                        Text(tab.rawValue)
                            .font(.system(size: 8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .foregroundColor(selectedTab == tab ? .accentBlue : .textTertiary)
                    .background(
                        selectedTab == tab ? Color.accentBlue.opacity(0.1) : Color.clear
                    )
                    .overlay(
                        Rectangle().frame(height: 2)
                            .foregroundColor(selectedTab == tab ? .accentBlue : .clear),
                        alignment: .bottom
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }
}
