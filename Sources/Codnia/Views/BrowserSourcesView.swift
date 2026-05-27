import SwiftUI

struct BrowserSourcesView: View {
    @ObservedObject var devToolsService: BrowserDevToolsService
    @State private var selectedResource: BrowserResourceEntry?
    @State private var searchText: String = ""

    private var groupedResources: [String: [BrowserResourceEntry]] {
        let dict = Dictionary(grouping: devToolsService.resources) { $0.domain }
        return dict
    }

    private var sortedDomains: [String] {
        groupedResources.keys.sorted()
    }

    private var filteredResources: [BrowserResourceEntry] {
        if searchText.isEmpty {
            return devToolsService.resources
        }
        return devToolsService.resources.filter {
            $0.url.localizedCaseInsensitiveContains(searchText) ||
            $0.domain.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if devToolsService.resources.isEmpty {
                emptyState
            } else if let selected = selectedResource {
                HSplitView {
                    resourceList
                    BrowserSourceFileView(resource: selected)
                        .frame(minWidth: 300)
                }
            } else {
                resourceList
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            Text("Sources")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textSecondary)
            Spacer()

            TextField("Filter...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.textPrimary)
                .frame(width: 120)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.bgTertiary)
                .cornerRadius(3)

            Text("\(devToolsService.resources.count) files")
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)

            Button(action: { devToolsService.refreshSources() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
            .help("Refresh sources")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 20))
                .foregroundColor(.textTertiary)
            Text("No sources loaded")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
            Text("Reload the page to capture resources")
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resourceList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                if searchText.isEmpty {
                    ForEach(sortedDomains, id: \.self) { domain in
                        Section(header: domainHeader(domain)) {
                            let entries = groupedResources[domain] ?? []
                            ForEach(entries.sorted(by: { $0.fileName < $1.fileName })) { entry in
                                ResourceRow(entry: entry, isSelected: selectedResource?.id == entry.id)
                                    .onTapGesture { selectedResource = entry }
                            }
                        }
                    }
                } else {
                    ForEach(filteredResources) { entry in
                        ResourceRow(entry: entry, isSelected: selectedResource?.id == entry.id)
                            .onTapGesture { selectedResource = entry }
                    }
                }
            }
        }
        .background(Color.bgPrimary)
        .frame(minWidth: 250)
    }

    private func domainHeader(_ domain: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "globe")
                .font(.system(size: 8))
                .foregroundColor(.textTertiary)
            Text(domain)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.textSecondary)
            Spacer()
            Text("\(groupedResources[domain]?.count ?? 0)")
                .font(.system(size: 8))
                .foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.bgTertiary)
    }
}

struct ResourceRow: View {
    let entry: BrowserResourceEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconForType(entry.pathExtension))
                .font(.system(size: 10))
                .foregroundColor(colorForType(entry.pathExtension))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.fileName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text(entry.domain)
                    .font(.system(size: 8))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isSelected ? Color.accentBlue.opacity(0.18) : Color.clear)
        .contentShape(Rectangle())
    }

    private func iconForType(_ ext: String) -> String {
        switch ext {
        case "js", "ts": return "swift"
        case "css": return "paintbrush"
        case "html", "htm": return "globe"
        case "json": return "curlybraces"
        case "png", "jpg", "gif", "svg", "webp": return "photo"
        case "woff", "woff2", "ttf", "otf": return "textformat"
        default: return "doc"
        }
    }

    private func colorForType(_ ext: String) -> Color {
        switch ext {
        case "js", "ts": return .accentYellow
        case "css": return .accentBlue
        case "html", "htm": return .accentOrange
        case "json": return .accentGreen
        default: return .textSecondary
        }
    }
}
