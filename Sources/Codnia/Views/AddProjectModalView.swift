import SwiftUI
import AppKit

struct AddProjectModalView: View {
    @Binding var isPresented: Bool
    var onSelect: (String) -> Void

    @State private var currentPath: String = NSHomeDirectory()
    @State private var entries: [FileEntry] = []
    @State private var pathBack: [String] = []
    @State private var pathForward: [String] = []
    @State private var showHidden: Bool = false
    @State private var searchQuery: String = ""
    @State private var selectedEntryPath: String?
    @State private var sortColumn: SortColumn = .name
    @State private var sortAscending: Bool = true
    @State private var sidebarSelection: SidebarLocation? = .documents
    @State private var collapsedSections: Set<SidebarSection> = []
    @State private var iconCache: [String: NSImage] = [:]
    @State private var newFolderAlert: NewFolderAlert?

    private let fileManager = FileManager.default

    private enum SortColumn: Equatable {
        case name, dateModified, size, kind
    }

    private struct NewFolderAlert: Identifiable {
        let id = UUID()
        let name: String
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                toolbarBar
                Divider().overlay(Color.borderDefault)
                HSplitView {
                    sidebar
                    mainContent
                }
                .layoutPriority(1)
                Divider().overlay(Color.borderDefault)
                bottomBar
            }
            .frame(minWidth: 720, idealWidth: 820, maxWidth: 1100,
                   minHeight: 520, idealHeight: 580)
            .background(Color.bgTertiary)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderLight, lineWidth: 1)
            )
            .padding(.top, 60)
            .alert(item: $newFolderAlert) { item in
                Alert(
                    title: Text("Folder name unavailable"),
                    message: Text("“\(item.name)” already exists or is invalid."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onAppear {
            loadEntries()
            primeIconCache(for: currentPath)
        }
        .onExitCommand { isPresented = false }
    }

    // MARK: - Toolbar / Path Bar

    private var toolbarBar: some View {
        HStack(spacing: 8) {
            Button(action: goBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(pathBack.isEmpty)
            .help("Back")

            Button(action: goForward) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(pathForward.isEmpty)
            .help("Forward")

            Button(action: goToParent) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(currentPath == "/")
            .help("Parent folder")

            breadcrumbView
                .layoutPriority(1)

            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
                TextField("Search", text: $searchQuery)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 11))
                    .frame(width: 120)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.bgSecondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )

            Button(action: { showHidden.toggle(); loadEntries() }) {
                Image(systemName: showHidden ? "eye.fill" : "eye.slash")
                    .font(.system(size: 11))
                    .frame(width: 22, height: 22)
                    .foregroundColor(showHidden ? .accentBlue : .textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
            .help(showHidden ? "Hide hidden files" : "Show hidden files")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.bgTertiary)
    }

    private var breadcrumbView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                let comps = pathComponents(of: currentPath)
                ForEach(Array(comps.enumerated()), id: \.offset) { i, comp in
                    if i > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7))
                            .foregroundColor(.textTertiary)
                    }
                    let partial = i == 0 ? "/" : "/" + comps[1...i].joined(separator: "/")
                    Button(action: { navigateTo(path: partial) }) {
                        Text(i == 0 ? "Macintosh HD" : comp)
                            .font(.system(size: 11, weight: i == comps.count - 1 ? .medium : .regular))
                            .foregroundColor(i == comps.count - 1 ? .textPrimary : .accentBlue)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        let locations = SidebarLocation.availableLocations()
        let grouped: [(SidebarSection, [SidebarLocation])] = SidebarSection.allCases.compactMap { section in
            let items = locations.filter { $0.section == section }
            return items.isEmpty ? nil : (section, items)
        }
        return List(selection: $sidebarSelection) {
            ForEach(grouped, id: \.0) { section, items in
                Section {
                    let collapsed = collapsedSections.contains(section)
                    if !collapsed {
                        ForEach(items) { loc in
                            sidebarRow(loc)
                                .tag(loc)
                        }
                    } else {
                        ForEach(items) { loc in
                            sidebarRow(loc)
                                .tag(loc)
                                .hidden()
                        }
                    }
                } header: {
                    HStack(spacing: 4) {
                        Image(systemName: collapsedSections.contains(section) ? "chevron.right" : "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.textTertiary)
                        Text(section.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.textSecondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if collapsedSections.contains(section) {
                            collapsedSections.remove(section)
                        } else {
                            collapsedSections.insert(section)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)
        .background(Color.bgSecondary)
        .onChange(of: sidebarSelection) { newValue in
            handleSidebarSelection(newValue)
        }
    }

    private func sidebarRow(_ loc: SidebarLocation) -> some View {
        HStack(spacing: 7) {
            Image(systemName: loc.systemImage)
                .font(.system(size: 12))
                .foregroundColor(iconColor(for: loc))
                .frame(width: 16)
            Text(loc.title)
                .font(.system(size: 12))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .opacity(loc.isSelectable ? 1.0 : 0.45)
    }

    private func iconColor(for loc: SidebarLocation) -> Color {
        switch loc {
        case .icloudDrive: return .accentBlue
        case .mobileDocuments: return .accentBlue
        case .desktop: return .accentBlue
        case .documents: return .folderYellow
        case .downloads: return .accentBlue
        case .pictures: return .accentBlue
        case .music: return .accentPink
        case .movies: return .accentBlue
        case .applications: return .accentBlue
        case .home: return .accentBlue
        case .airDrop, .recents: return .accentBlue
        case .volume: return .textSecondary
        case .root: return .textSecondary
        }
    }

    private func handleSidebarSelection(_ loc: SidebarLocation?) {
        guard let loc = loc, let p = loc.path, loc.isSelectable else { return }
        if p == currentPath { return }
        navigateTo(path: p)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            columnHeader
            Divider().overlay(Color.borderDefault)
            entryList
        }
        .background(Color.bgPrimary)
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            columnHeaderCell("Name", column: .name, width: nil, alignment: .leading, flex: true)
            Divider().overlay(Color.borderDefault).frame(width: 1)
            columnHeaderCell("Date Modified", column: .dateModified, width: 150, alignment: .leading, flex: false)
            Divider().overlay(Color.borderDefault).frame(width: 1)
            columnHeaderCell("Size", column: .size, width: 80, alignment: .trailing, flex: false)
            Divider().overlay(Color.borderDefault).frame(width: 1)
            columnHeaderCell("Kind", column: .kind, width: 100, alignment: .leading, flex: false)
        }
        .frame(height: 24)
        .background(Color.bgSecondary)
    }

    private func columnHeaderCell(
        _ title: String,
        column: SortColumn,
        width: CGFloat?,
        alignment: Alignment,
        flex: Bool
    ) -> some View {
        let isActive = sortColumn == column
        let indicator: String = {
            guard isActive else { return "" }
            return sortAscending ? "↑" : "↓"
        }()
        return Button {
            toggleSort(column)
        } label: {
            HStack(spacing: 4) {
                if alignment == .trailing { Spacer(minLength: 0) }
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isActive ? .textPrimary : .textSecondary)
                if !indicator.isEmpty {
                    Text(indicator)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.textSecondary)
                }
                if alignment == .leading { Spacer(minLength: 0) }
            }
            .padding(.horizontal, 8)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: flex ? .infinity : nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func toggleSort(_ column: SortColumn) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
    }

    private var filteredEntries: [FileEntry] {
        let base: [FileEntry]
        if showHidden {
            base = entries
        } else {
            base = entries.filter { !$0.isHidden }
        }
        if searchQuery.isEmpty { return base }
        let q = searchQuery.lowercased()
        return base.filter { $0.name.lowercased().contains(q) }
    }

    private var entryList: some View {
        let sorted = sortedEntries(filteredEntries)
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if currentPath != "/" {
                        parentRow
                    }
                    if sorted.isEmpty {
                        emptyState
                    } else {
                        ForEach(sorted) { entry in
                            entryRow(entry)
                                .id(entry.path)
                                .onTapGesture(count: 2) { navigateToEntry(entry) }
                                .onTapGesture { selectedEntryPath = entry.path }
                                .contextMenu {
                                    if entry.isDirectory {
                                        Button("Open") { navigateToEntry(entry) }
                                    }
                                    Button("Reveal in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: entry.path)])
                                    }
                                }
                        }
                    }
                }
            }
            .onChange(of: currentPath) { _ in
                selectedEntryPath = nil
            }
            .onChange(of: sortColumn) { _ in
                if let sel = selectedEntryPath {
                    proxy.scrollTo(sel, anchor: .center)
                }
            }
            .onChange(of: sortAscending) { _ in
                if let sel = selectedEntryPath {
                    proxy.scrollTo(sel, anchor: .center)
                }
            }
        }
        .background(Color.bgPrimary)
    }

    private func sortedEntries(_ items: [FileEntry]) -> [FileEntry] {
        let result = items.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            let cmp: ComparisonResult
            switch sortColumn {
            case .name:
                cmp = a.name.localizedStandardCompare(b.name)
            case .dateModified:
                let ad = a.dateModified ?? .distantPast
                let bd = b.dateModified ?? .distantPast
                cmp = ad.compare(bd)
            case .size:
                let as_ = a.isDirectory ? -1 : (a.fileSize ?? 0)
                let bs = b.isDirectory ? -1 : (b.fileSize ?? 0)
                if as_ == bs { cmp = .orderedSame }
                else { cmp = as_ < bs ? .orderedAscending : .orderedDescending }
            case .kind:
                cmp = (a.kind ?? "").localizedStandardCompare(b.kind ?? "")
            }
            let primary = cmp == .orderedSame
                ? a.name.localizedStandardCompare(b.name) == .orderedAscending
                : (sortAscending ? cmp == .orderedAscending : cmp == .orderedDescending)
            return primary
        }
        return result
    }

    private var parentRow: some View {
        Button(action: goToParent) {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                        .frame(width: 16)
                    Text("..")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("—")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
                    .frame(width: 150, alignment: .leading)
                    .padding(.horizontal, 8)
                Text("—")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
                    .frame(width: 80, alignment: .trailing)
                    .padding(.horizontal, 8)
                Text("Folder")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
                    .frame(width: 100, alignment: .leading)
                    .padding(.horizontal, 8)
            }
            .frame(height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 50)
            Image(systemName: "folder")
                .font(.system(size: 28))
                .foregroundColor(.textTertiary)
            Text(searchQuery.isEmpty ? "No subdirectories" : "No matches")
                .font(.system(size: 12))
                .foregroundColor(.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func entryRow(_ entry: FileEntry) -> some View {
        let isSelected = selectedEntryPath == entry.path
        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                iconView(for: entry)
                    .frame(width: 16, height: 16)
                Text(entry.name)
                    .font(.system(size: 12))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(formattedDate(entry.dateModified))
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
                .padding(.horizontal, 8)

            Text(formattedSize(entry))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.textSecondary)
                .frame(width: 80, alignment: .trailing)
                .padding(.horizontal, 8)

            Text(entry.kind ?? (entry.isDirectory ? "Folder" : "File"))
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .frame(width: 100, alignment: .leading)
                .padding(.horizontal, 8)
        }
        .frame(height: 24)
        .background(isSelected ? Color.accentBlue.opacity(0.25) : Color.clear)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func iconView(for entry: FileEntry) -> some View {
        if let nsImage = cachedIcon(for: entry.path) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                .foregroundColor(entry.isDirectory ? .folderYellow : .textSecondary)
        }
    }

    private func cachedIcon(for path: String) -> NSImage? {
        if let cached = iconCache[path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: 16, height: 16)
        iconCache[path] = image
        return image
    }

    private func primeIconCache(for path: String) {
        let paths = entries.map { $0.path }
        DispatchQueue.global(qos: .userInitiated).async { [paths] in
            var cache: [String: NSImage] = [:]
            for p in paths {
                let image = NSWorkspace.shared.icon(forFile: p)
                image.size = NSSize(width: 16, height: 16)
                cache[p] = image
            }
            DispatchQueue.main.async {
                self.iconCache.merge(cache) { _, new in new }
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(action: createNewFolder) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 11))
                    Text("New Folder")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Create a new folder here")

            Spacer()

            Text(FileSystemService.displayPath(for: currentPath))
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 320)

            Button(action: { isPresented = false }) {
                Text("Cancel")
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut(.cancelAction)

            Button(action: confirm) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                    Text("Add Project")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.accentBlue)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgTertiary)
    }

    // MARK: - Loading and navigation

    private func loadEntries() {
        let path = currentPath
        let showHidden = self.showHidden
        DispatchQueue.global(qos: .userInitiated).async {
            let result = FileSystemService.shared.listDirectory(path: path)
            DispatchQueue.main.async {
                if self.currentPath == path {
                    self.entries = showHidden ? result : result.filter { !$0.isHidden }
                    self.primeIconCache(for: path)
                }
            }
        }
    }

    private func navigateTo(path: String) {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return }
        guard path != currentPath else { return }
        pathBack.append(currentPath)
        pathForward.removeAll()
        currentPath = path
        loadEntries()
    }

    private func navigateToEntry(_ entry: FileEntry) {
        guard entry.isDirectory else { return }
        navigateTo(path: entry.path)
    }

    private func goToParent() {
        guard currentPath != "/" else { return }
        let parent = URL(fileURLWithPath: currentPath).deletingLastPathComponent().path
        navigateTo(path: parent)
    }

    private func goBack() {
        guard let previous = pathBack.popLast() else { return }
        pathForward.append(currentPath)
        currentPath = previous
        loadEntries()
    }

    private func goForward() {
        guard let next = pathForward.popLast() else { return }
        pathBack.append(currentPath)
        currentPath = next
        loadEntries()
    }

    private func confirm() {
        let path = currentPath
        onSelect(path)
        isPresented = false
    }

    private func createNewFolder() {
        let alert = NSAlert()
        alert.messageText = "New Folder"
        alert.informativeText = "Choose a name for the new folder in \(FileSystemService.displayPath(for: currentPath))"
        alert.alertStyle = .informational
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.placeholderString = "untitled folder"
        textField.stringValue = ""
        alert.accessoryView = textField
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let newPath = URL(fileURLWithPath: currentPath).appendingPathComponent(name).path
        if FileManager.default.fileExists(atPath: newPath) {
            newFolderAlert = NewFolderAlert(name: name)
            return
        }
        do {
            try FileManager.default.createDirectory(atPath: newPath, withIntermediateDirectories: false)
            loadEntries()
        } catch {
            newFolderAlert = NewFolderAlert(name: name)
        }
    }

    // MARK: - Helpers

    private func pathComponents(of path: String) -> [String] {
        URL(fileURLWithPath: path).pathComponents
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }

    private func formattedSize(_ entry: FileEntry) -> String {
        if entry.isDirectory { return "—" }
        guard let size = entry.fileSize else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

extension Color {
    static let accentPink = Color(hex: "#ec4899")
}
