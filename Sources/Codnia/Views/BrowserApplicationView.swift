import SwiftUI

struct BrowserApplicationView: View {
    @ObservedObject var devToolsService: BrowserDevToolsService
    @State private var showClearAlert: Bool = false
    @State private var clearTypes: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if devToolsService.isAppLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        manifestSection
                        serviceWorkerSection
                        cacheSection
                        clearDataSection
                    }
                }
                .background(Color.bgPrimary)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            Text("Application")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textSecondary)
            Spacer()
            Button(action: { devToolsService.refreshApplication() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
            .help("Refresh application data")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
    }

    // MARK: - Manifest

    private var manifestSection: some View {
        Section(header: sectionHeader("Manifest", icon: "doc.text.below.ecg")) {
            if let manifest = devToolsService.manifestInfo {
                VStack(alignment: .leading, spacing: 4) {
                    if let name = manifest.name {
                        infoRow(label: "Name", value: name)
                    }
                    if let short = manifest.shortName {
                        infoRow(label: "Short Name", value: short)
                    }
                    if let desc = manifest.description {
                        infoRow(label: "Description", value: desc)
                    }
                    if let start = manifest.startURL {
                        infoRow(label: "Start URL", value: start)
                    }
                    if let display = manifest.display {
                        infoRow(label: "Display", value: display)
                    }
                    if let theme = manifest.themeColor {
                        HStack(spacing: 4) {
                            infoRow(label: "Theme Color", value: theme)
                            Circle()
                                .fill(Color.fromHex(theme))
                                .frame(width: 10, height: 10)
                        }
                    }
                    if let bg = manifest.backgroundColor {
                        HStack(spacing: 4) {
                            infoRow(label: "Background", value: bg)
                            Circle()
                                .fill(Color.fromHex(bg))
                                .frame(width: 10, height: 10)
                        }
                    }
                    if !manifest.icons.isEmpty {
                        Text("Icons (\(manifest.icons.count))")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.textSecondary)
                            .padding(.top, 4)
                        ForEach(manifest.icons.indices, id: \.self) { i in
                            let icon = manifest.icons[i]
                            Text("\(icon.sizes) — \(icon.src)")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            } else {
                emptySection("No manifest detected")
            }
        }
    }

    // MARK: - Service Worker

    private var serviceWorkerSection: some View {
        Section(header: sectionHeader("Service Worker", icon: "arrow.triangle.branch")) {
            if let sw = devToolsService.serviceWorkerInfo {
                VStack(alignment: .leading, spacing: 4) {
                    infoRow(label: "Script URL", value: sw.scriptURL)
                    HStack(spacing: 4) {
                        Text("State:")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.textSecondary)
                            .frame(width: 80, alignment: .trailing)
                        Circle()
                            .fill(sw.isActive ? Color.accentGreen : Color.accentYellow)
                            .frame(width: 6, height: 6)
                        Text(sw.state)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.textPrimary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            } else {
                emptySection("No service worker registered")
            }
        }
    }

    // MARK: - Cache Storage

    private var cacheSection: some View {
        Section(header: sectionHeader("Cache Storage", icon: "cylinder.split.1x2")) {
            if devToolsService.cacheStorage.isEmpty {
                emptySection("No cache entries")
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(devToolsService.cacheStorage) { cache in
                        HStack(spacing: 6) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 8))
                                .foregroundColor(.textTertiary)
                            Text(cache.name)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.textPrimary)
                            Spacer()
                            Text(formatBytes(Int(cache.size)))
                                .font(.system(size: 8))
                                .foregroundColor(.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Clear Data

    private var clearDataSection: some View {
        Section(header: sectionHeader("Clear Data", icon: "trash")) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Select data to clear:")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.textSecondary)

                let clearOptions = ["localStorage", "sessionStorage", "cookies", "cache"]
                ForEach(clearOptions, id: \.self) { option in
                    let label: String = {
                        switch option {
                        case "localStorage": return "Local Storage"
                        case "sessionStorage": return "Session Storage"
                        case "cookies": return "Cookies"
                        case "cache": return "Cache Storage"
                        default: return option
                        }
                    }()
                    Toggle(isOn: Binding(
                        get: { clearTypes.contains(option) },
                        set: { if $0 { clearTypes.insert(option) } else { clearTypes.remove(option) } }
                    )) {
                        Text(label)
                            .font(.system(size: 10))
                    }
                    .toggleStyle(.checkbox)
                }

                Button(action: { showClearAlert = true }) {
                    Text("Clear Selected Data")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(clearTypes.isEmpty ? Color.accentRed.opacity(0.3) : Color.accentRed)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(clearTypes.isEmpty)
                .alert("Clear browser data?", isPresented: $showClearAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear", role: .destructive) {
                        devToolsService.clearBrowserData(types: Array(clearTypes))
                        clearTypes.removeAll()
                    }
                } message: {
                    Text("This will clear \(clearTypes.map { $0.capitalized }.joined(separator: ", ")) for this site.")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.bgTertiary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label + ":")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.textSecondary)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.textPrimary)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }

    private func emptySection(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundColor(.textTertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes)B" }
        if bytes < 1024 * 1024 { return String(format: "%.1fKB", Double(bytes) / 1024) }
        return String(format: "%.1fMB", Double(bytes) / (1024 * 1024))
    }
}

extension Color {
    static func fromHex(_ hex: String) -> Color {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") {
            sanitized.removeFirst()
        }
        guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else {
            return .clear
        }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
