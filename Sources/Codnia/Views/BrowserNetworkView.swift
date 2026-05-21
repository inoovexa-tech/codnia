import SwiftUI

struct BrowserNetworkView: View {
    @ObservedObject var devToolsService: BrowserDevToolsService

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if devToolsService.networkEntries.isEmpty {
                emptyState
            } else {
                requestList
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            Text("Network")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textSecondary)
            Spacer()
            Text("\(devToolsService.networkEntries.count) requests")
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
            Button(action: { devToolsService.clearNetwork() }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
            .help("Clear network log")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.up.arrow.down.circle")
                .font(.system(size: 20))
                .foregroundColor(.textTertiary)
            Text("No network requests captured")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
            Text("Reload the page to capture requests")
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var requestList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(devToolsService.networkEntries) { entry in
                    NetworkEntryRow(entry: entry)
                    Divider()
                        .background(Color.borderDefault.opacity(0.3))
                }
            }
        }
        .background(Color.bgPrimary)
    }
}

struct NetworkEntryRow: View {
    let entry: BrowserNetworkEntry
    @State private var showDetails: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.12)) { showDetails.toggle() } }) {
                HStack(spacing: 6) {
                    // method badge
                    Text(entry.method)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(methodColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(methodColor.opacity(0.12))
                        .cornerRadius(3)
                        .frame(width: 44, alignment: .center)

                    // status
                    Text("\(entry.status)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(entry.statusColor)
                        .frame(width: 32, alignment: .trailing)

                    // path
                    Text(entry.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    // duration
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text(durationText)
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundColor(.textTertiary)
                    .frame(width: 64, alignment: .trailing)

                    // size
                    Text(sizeText)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.textTertiary)
                        .frame(width: 56, alignment: .trailing)

                    // expand indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(.textTertiary)
                        .rotationEffect(.degrees(showDetails ? 180 : 0))
                        .frame(width: 12)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if showDetails {
                VStack(alignment: .leading, spacing: 4) {
                    detailRow(label: "URL", value: entry.url)
                    if let ct = entry.contentType, !ct.isEmpty {
                        detailRow(label: "Content-Type", value: ct)
                    }
                    detailRow(label: "Duration", value: String(format: "%.1f ms", entry.duration))
                    detailRow(label: "Response Size", value: formatBytes(entry.responseSize))
                    if !entry.responseHeaders.isEmpty {
                        Text("Response Headers:")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.textSecondary)
                            .padding(.top, 2)
                        ForEach(Array(entry.responseHeaders.sorted(by: { $0.key < $1.key })), id: \.key) { k, v in
                            Text("  \(k): \(v)")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.bgHover)
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label + ":")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.textSecondary)
                .frame(width: 90, alignment: .trailing)
            Text(value)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.textPrimary)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }

    private var methodColor: Color {
        switch entry.method {
        case "GET":    return .accentGreen
        case "POST":   return .accentBlue
        case "PUT":    return .accentOrange
        case "PATCH":  return .accentYellow
        case "DELETE": return .accentRed
        default:       return .textSecondary
        }
    }

    private var durationText: String {
        if entry.duration < 1000 {
            return String(format: "%.0fms", entry.duration)
        }
        return String(format: "%.1fs", entry.duration / 1000)
    }

    private var sizeText: String {
        formatBytes(entry.responseSize)
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes)B" }
        if bytes < 1024 * 1024 { return String(format: "%.1fKB", Double(bytes) / 1024) }
        return String(format: "%.1fMB", Double(bytes) / (1024 * 1024))
    }
}
