import SwiftUI

struct BrowserNetworkView: View {
    @ObservedObject var devToolsService: BrowserDevToolsService
    @State private var showOptions: Bool = false
    @State private var searchText: String = ""
    @State private var hostFilter: String = ""

    private var availableHosts: [String] {
        let hosts = Set(devToolsService.networkEntries.map { $0.host })
        return hosts.sorted()
    }

    private var filteredEntries: [BrowserNetworkEntry] {
        var result = devToolsService.networkEntries
        if devToolsService.networkFilter != .all {
            result = result.filter { devToolsService.networkFilter.matches($0) }
        }
        if !hostFilter.isEmpty {
            result = result.filter { $0.host == hostFilter }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.url.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            filterBar
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

            TextField("Filter URL...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.textPrimary)
                .frame(width: 140)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.bgTertiary)
                .cornerRadius(3)

            Menu {
                Button(action: { hostFilter = "" }) {
                    HStack {
                        Text("All hosts")
                        if hostFilter.isEmpty {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Divider()
                ForEach(availableHosts, id: \.self) { host in
                    Button(action: { hostFilter = host }) {
                        HStack {
                            Text(host)
                            if hostFilter == host {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "globe")
                        .font(.system(size: 9))
                    Text(hostFilter.isEmpty ? "All" : hostFilter)
                        .font(.system(size: 9, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.bgTertiary)
                .cornerRadius(3)
                .frame(maxWidth: 110)
                .foregroundColor(.textSecondary)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .menuIndicator(.hidden)

            Text("\(devToolsService.networkEntries.count) requests")
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)

            Button(action: { showOptions.toggle() }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
            .help("Options")
            .popover(isPresented: $showOptions, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $devToolsService.preserveNetworkLog) {
                        Text("Preserve log")
                            .font(.system(size: 11))
                    }
                    .toggleStyle(.checkbox)
                }
                .padding(10)
                .frame(width: 150)
            }

            Button(action: { devToolsService.clearNetwork() }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
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

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(BrowserDevToolsService.NetworkFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        devToolsService.networkFilter = devToolsService.networkFilter == filter ? .all : filter
                    }) {
                        Text(filter.rawValue)
                            .font(.system(size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .foregroundColor(devToolsService.networkFilter == filter ? .accentBlue : .textTertiary)
                            .background(devToolsService.networkFilter == filter ? Color.accentBlue.opacity(0.12) : Color.clear)
                            .cornerRadius(3)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 3)
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
                headerRow
                ForEach(filteredEntries) { entry in
                    NetworkEntryRow(entry: entry)
                    Divider()
                        .background(Color.borderDefault.opacity(0.3))
                }
            }
        }
        .background(Color.bgPrimary)
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Text("Method")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.textTertiary)
                .frame(width: 44, alignment: .center)
            Text("Status")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.textTertiary)
                .frame(width: 32, alignment: .trailing)
            Text("File")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Initiator")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.textTertiary)
                .frame(width: 70, alignment: .leading)
            Text("Timing")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.textTertiary)
                .frame(width: 64, alignment: .trailing)
            Text("Size")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.textTertiary)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.bgTertiary)
    }
}

struct NetworkEntryRow: View {
    let entry: BrowserNetworkEntry
    @State private var showDetails: Bool = false

    private let waterfallMax: Double = 2000

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.12)) { showDetails.toggle() } }) {
                HStack(spacing: 6) {
                    Text(entry.method)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(methodColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(methodColor.opacity(0.12))
                        .cornerRadius(3)
                        .frame(width: 44, alignment: .center)

                    Text("\(entry.status)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(entry.statusColor)
                        .frame(width: 32, alignment: .trailing)

                    HStack(spacing: 0) {
                        Text(entry.path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                        if entry.duration > 0 {
                            waterfallBar
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(entry.initiator ?? "")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.textTertiary)
                        .lineLimit(1)
                        .frame(width: 70, alignment: .leading)

                    Text(durationText)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.textTertiary)
                        .frame(width: 64, alignment: .trailing)

                    Text(sizeText)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.textTertiary)
                        .frame(width: 48, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .contextMenu {
                Button("Copy URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.url, forType: .string)
                }
                Button("Copy as cURL") {
                    entry.copyAsCurlToPasteboard()
                }
                Divider()
                Button("Copy Response Body") {
                    if let body = entry.responseBody {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(body, forType: .string)
                    }
                }
                .disabled(entry.responseBody == nil)
                Button("Copy Request Body") {
                    if let body = entry.requestBody {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(body, forType: .string)
                    }
                }
                .disabled(entry.requestBody == nil)
                Divider()
                Button(entry.host) {}
                    .disabled(true)
            }

            if showDetails {
                detailPanel
            }
        }
    }

    private var waterfallBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.borderLight)
                    .frame(width: geo.size.width, height: 4)
                    .cornerRadius(2)
                Rectangle()
                    .fill(waterfallColor)
                    .frame(width: max(4, geo.size.width * min(1, CGFloat(entry.duration / waterfallMax))), height: 4)
                    .cornerRadius(2)
            }
        }
        .frame(width: 40)
        .padding(.leading, 4)
    }

    private var waterfallColor: Color {
        if entry.duration < 100 { return .accentGreen }
        if entry.duration < 500 { return .accentBlue }
        if entry.duration < 1000 { return .accentYellow }
        return .accentRed
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("", selection: .constant(0)) {
                Text("Headers").tag(0)
                Text("Request").tag(1)
                Text("Response").tag(2)
                Text("Timing").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)

            detailContent
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.bgHover)
    }

    @ViewBuilder
    private var detailContent: some View {
        detailRow(label: "URL", value: entry.url)

        if !entry.requestHeaders.isEmpty {
            Text("Request Headers:")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.textSecondary)
            ForEach(Array(entry.requestHeaders.sorted(by: { $0.key < $1.key })), id: \.key) { k, v in
                Text("  \(k): \(v)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
        }

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
                    .textSelection(.enabled)
            }
        }

        if let reqBody = entry.requestBody, !reqBody.isEmpty {
            Text("Request Body:")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.textSecondary)
                .padding(.top, 2)
            Text(reqBody.prefix(2000))
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.textPrimary)
                .textSelection(.enabled)
                .lineLimit(10)
        }

        if let respBody = entry.responseBody, !respBody.isEmpty {
            Text("Response Body:")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.textSecondary)
                .padding(.top, 2)
            Text(respBody.prefix(2000))
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.textPrimary)
                .textSelection(.enabled)
                .lineLimit(10)
        }

        if let ct = entry.contentType, !ct.isEmpty {
            detailRow(label: "Content-Type", value: ct)
        }
        if let addr = entry.remoteAddress, !addr.isEmpty {
            detailRow(label: "Remote Address", value: addr)
        }
        detailRow(label: "Duration", value: String(format: "%.1f ms", entry.duration))
        detailRow(label: "Response Size", value: formatBytes(entry.responseSize))
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label + ":")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.textSecondary)
                .frame(width: 100, alignment: .trailing)
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
