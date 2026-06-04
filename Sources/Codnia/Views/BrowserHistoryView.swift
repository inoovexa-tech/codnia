import SwiftUI

struct BrowserHistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var confirmClear: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            content
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            TextField("Search history", text: $appState.historyService.searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.bgTertiary)
                .cornerRadius(3)

            Text("\(appState.historyService.entries.count)")
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)

            Button(action: { confirmClear = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.accentRed)
            .help("Clear history")
            .disabled(appState.historyService.entries.isEmpty)
            .alert("Clear all browsing history?", isPresented: $confirmClear) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    appState.historyService.clearAll()
                }
            } message: {
                Text("This will permanently remove all recorded visits for this worktree.")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private var content: some View {
        if appState.historyService.entries.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(appState.historyService.groupedByDay, id: \.day) { group in
                        sectionHeader(group.day)
                        ForEach(group.items) { entry in
                            HistoryRow(
                                entry: entry,
                                onOpen: { openHistoryEntry(entry) },
                                onDelete: { appState.historyService.remove(entry) }
                            )
                        }
                    }
                }
            }
            .background(Color.bgPrimary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 20))
                .foregroundColor(.textTertiary)
            Text("No browsing history")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
            Text("Visited pages will appear here")
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionHeader(_ day: String) -> some View {
        HStack {
            Text(day)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.bgTertiary.opacity(0.3))
    }

    private func openHistoryEntry(_ entry: BrowserHistoryEntry) {
        appState.openURL(entry.url, in: .tab)
    }
}

struct HistoryRow: View {
    let entry: BrowserHistoryEntry
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.system(size: 10))
                .foregroundColor(.accentBlue)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title.isEmpty ? entry.host : entry.title)
                    .font(.system(size: 10))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(entry.host)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.textTertiary)
                        .lineLimit(1)
                    Text("·")
                        .font(.system(size: 8))
                        .foregroundColor(.textTertiary)
                    Text(timeAgo(entry.visitedAt))
                        .font(.system(size: 8))
                        .foregroundColor(.textTertiary)
                    if entry.visitCount > 1 {
                        Text("·")
                            .font(.system(size: 8))
                            .foregroundColor(.textTertiary)
                        Text("\(entry.visitCount)×")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.accentBlue)
                    }
                }
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundColor(.textTertiary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onOpen() }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}
