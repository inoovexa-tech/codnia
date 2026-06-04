import SwiftUI
import AppKit

struct BrowserDownloadsView: View {
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
            Text("Downloads")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textSecondary)
            Spacer()
            Text("\(appState.downloadService.downloads.count)")
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
            Button(action: { confirmClear = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.accentRed)
            .help("Clear completed")
            .disabled(appState.downloadService.downloads.isEmpty)
            .alert("Clear completed downloads?", isPresented: $confirmClear) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    appState.downloadService.clearCompleted()
                }
            } message: {
                Text("This removes completed, cancelled, and failed downloads from the list.")
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
        if appState.downloadService.downloads.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(appState.downloadService.downloads) { download in
                        DownloadRow(
                            download: download,
                            onCancel: { appState.downloadService.cancel(download) },
                            onRemove: { appState.downloadService.remove(download) },
                            onReveal: { appState.downloadService.revealInFinder(download) }
                        )
                        Divider()
                            .background(Color.borderDefault.opacity(0.2))
                    }
                }
            }
            .background(Color.bgPrimary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 20))
                .foregroundColor(.textTertiary)
            Text("No downloads")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
            Text("Files you download will appear here")
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DownloadRow: View {
    let download: BrowserDownload
    let onCancel: () -> Void
    let onRemove: () -> Void
    let onReveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(iconColor)
                    .frame(width: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text(download.suggestedFilename)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(stateDescription)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.textTertiary)
                }
                Spacer()
                actionMenu
            }
            if download.state == .downloading || download.state == .pending {
                ProgressView(value: download.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentBlue))
                    .frame(height: 2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var icon: String {
        switch download.state {
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.octagon.fill"
        case .cancelled: return "minus.circle"
        case .paused: return "pause.circle"
        case .downloading, .pending: return "arrow.down.circle.fill"
        }
    }

    private var iconColor: Color {
        switch download.state {
        case .completed: return .accentGreen
        case .failed: return .accentRed
        case .cancelled: return .textTertiary
        case .paused: return .accentYellow
        case .downloading, .pending: return .accentBlue
        }
    }

    private var stateDescription: String {
        switch download.state {
        case .pending: return "Pending…"
        case .downloading:
            return "\(download.displaySize) / \(formatBytes(download.totalBytes))"
        case .completed:
            return "Completed · \(download.displaySize)"
        case .failed:
            return "Failed: \(download.errorMessage ?? "Unknown")"
        case .cancelled:
            return "Cancelled"
        case .paused:
            return "Paused"
        }
    }

    private var actionMenu: some View {
        Menu {
            if download.state == .downloading || download.state == .pending {
                Button("Cancel", role: .destructive, action: onCancel)
            }
            if download.state == .completed {
                Button("Reveal in Finder", action: onReveal)
            }
            Divider()
            Button("Remove from list", role: .destructive, action: onRemove)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
                .frame(width: 16, height: 16)
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
        return String(format: "%.2f GB", Double(bytes) / (1024 * 1024 * 1024))
    }
}
