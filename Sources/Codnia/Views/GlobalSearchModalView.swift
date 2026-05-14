import SwiftUI
import AppKit

struct GlobalSearchModalView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var searchVM: SearchService
    @EnvironmentObject var workspaceVM: WorkspaceService
    @EnvironmentObject var editorVM: EditorViewModel

    @State private var query: String = ""
    @State private var useRegex: Bool = false
    @State private var caseSensitive: Bool = false
    @State private var searchMode: SearchMode = .all
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedResultId: String?
    @State private var eventMonitor: Any?
    @FocusState private var isSearchFieldFocused: Bool

    private var flatResults: [SearchResult] {
        searchVM.globalResults
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    searchHeader
                    modeBar
                }

                if !query.isEmpty && !flatResults.isEmpty {
                    resultsListWithScroll
                } else if searchVM.isGlobalSearching {
                    resultsLoading
                } else if !query.isEmpty && flatResults.isEmpty {
                    resultsEmpty
                }
            }
            .frame(width: 640)
            .background(Color.bgTertiary)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderLight, lineWidth: 1)
            )
            .padding(.top, 8)
        }
        .onAppear {
            isSearchFieldFocused = true
            setupEventMonitor()
        }
        .onDisappear {
            removeEventMonitor()
        }
        .onExitCommand {
            if query.isEmpty {
                isPresented = false
            } else {
                query = ""
                searchVM.globalResults = []
            }
        }
        .onChange(of: flatResults.count) { count in
            if count > 0 {
                selectedResultId = flatResults[0].id
            } else {
                selectedResultId = nil
            }
        }
    }

    // MARK: - Event Monitor (keyboard navigation)

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [self] event in
            self.handleKeyEvent(event)
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        if flatResults.isEmpty {
            return event
        }

        switch event.keyCode {
        case 125:
            moveSelection(down: true)
            return nil
        case 126:
            moveSelection(down: false)
            return nil
        case 36:
            if let id = selectedResultId,
               let result = flatResults.first(where: { $0.id == id }) {
                selectResult(result)
            }
            return nil
        default:
            return event
        }
    }

    private func moveSelection(down: Bool) {
        guard !flatResults.isEmpty else { return }
        let currentIndex = flatResults.firstIndex(where: { $0.id == selectedResultId }) ?? -1
        let newIndex: Int
        if down {
            newIndex = min(currentIndex + 1, flatResults.count - 1)
        } else {
            newIndex = currentIndex <= 0 ? 0 : currentIndex - 1
        }
        selectedResultId = flatResults[newIndex].id
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textTertiary)
                .font(.system(size: 14))

            TextField("Search across all projects...", text: $query)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
                .focused($isSearchFieldFocused)
                .onSubmit(performSearch)
                .onChange(of: query) { newValue in
                    searchTask?.cancel()
                    if newValue.isEmpty {
                        searchVM.globalResults = []
                        selectedResultId = nil
                    } else {
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            guard !Task.isCancelled else { return }
                            performSearch()
                        }
                    }
                }

            if !query.isEmpty {
                Button(action: { query = ""; searchVM.globalResults = []; selectedResultId = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textTertiary)
                        .font(.system(size: 13))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Mode Bar

    private var modeBar: some View {
        HStack(spacing: 4) {
            filterChip(label: "Regex", isOn: $useRegex)
            filterChip(label: "Case", isOn: $caseSensitive)

            Spacer()

            Picker("", selection: $searchMode) {
                ForEach(SearchMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
            .onChange(of: searchMode) { _ in
                if !query.isEmpty {
                    performSearch()
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
    }

    private func filterChip(label: String, isOn: Binding<Bool>) -> some View {
        Button(action: { isOn.wrappedValue.toggle() }) {
            HStack(spacing: 3) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 10))
                    .foregroundColor(isOn.wrappedValue ? .accentBlue : .textTertiary)
                Text(label)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isOn.wrappedValue ? Color.accentBlue.opacity(0.15) : Color.bgHover)
            .foregroundColor(isOn.wrappedValue ? .accentBlue : .textSecondary)
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Results States

    private var resultsLoading: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 80)
            ProgressView()
                .scaleEffect(0.8)
                .progressViewStyle(CircularProgressViewStyle(tint: .textSecondary))
            Spacer().frame(height: 80)
        }
        .frame(maxWidth: .infinity)
    }

    private var resultsEmpty: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 80)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(.textTertiary)
            Text("No matches")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
            Spacer().frame(height: 80)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Results with Scroll

    private var resultsListWithScroll: some View {
        let groups = buildGroups(from: flatResults)
        return ScrollViewReader { proxy in
            List {
                ForEach(groups) { projectGroup in
                    ProjectResultSectionList(
                        projectGroup: projectGroup,
                        allResults: flatResults,
                        selectedResultId: selectedResultId,
                        query: query,
                        onSelect: { result in selectResult(result) }
                    )
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.visible)
            .onChange(of: selectedResultId) { id in
                if let id = id {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .frame(maxHeight: 440)
        }
    }

    // MARK: - Actions

    private func performSearch() {
        let projects = workspaceVM.projects
        guard !projects.isEmpty else { return }
        searchVM.searchGlobal(
            projects: projects,
            query: query,
            maxResults: 500,
            isRegex: useRegex,
            caseSensitive: caseSensitive,
            mode: searchMode
        )
    }

    private func selectResult(_ result: SearchResult) {
        isPresented = false
        query = ""
        searchVM.globalResults = []
        selectedResultId = nil
        removeEventMonitor()
        editorVM.openFileInWorktree(
            path: result.filePath,
            projectId: result.projectId,
            worktreeId: result.worktreeId,
            searchQuery: query
        )
    }

    // MARK: - Grouping

    private func buildGroups(from results: [SearchResult]) -> [ProjectGroup] {
        let projectDict = Dictionary(grouping: results) { $0.projectId }
        return projectDict.map { projectId, projectResults in
            let name = projectResults.first?.projectName ?? projectId
            let worktreeDict = Dictionary(grouping: projectResults) { $0.worktreeId }
            let worktreeGroups = worktreeDict.map { worktreeId, worktreeResults -> WorktreeGroup in
                WorktreeGroup(
                    id: worktreeId,
                    worktreeName: worktreeResults.first?.worktreeName ?? worktreeId,
                    results: worktreeResults
                )
            }
            .sorted { $0.worktreeName < $1.worktreeName }

            return ProjectGroup(
                id: projectId,
                projectName: name,
                worktreeGroups: worktreeGroups
            )
        }
        .sorted { $0.projectName < $1.projectName }
    }
}

// MARK: - Grouping Types

struct ProjectGroup: Identifiable {
    let id: String
    let projectName: String
    let worktreeGroups: [WorktreeGroup]
}

struct WorktreeGroup: Identifiable {
    let id: String
    let worktreeName: String
    let results: [SearchResult]
}

// MARK: - Project Result Section (List variant)

struct ProjectResultSectionList: View {
    let projectGroup: ProjectGroup
    let allResults: [SearchResult]
    let selectedResultId: String?
    let query: String
    let onSelect: (SearchResult) -> Void
    @State private var isExpanded: Bool = true

    var body: some View {
        Section {
            if isExpanded {
                ForEach(projectGroup.worktreeGroups) { worktreeGroup in
                    WorktreeResultSectionList(
                        worktreeGroup: worktreeGroup,
                        allResults: allResults,
                        selectedResultId: selectedResultId,
                        query: query,
                        onSelect: onSelect
                    )
                }
            }
        } header: {
            Button(action: { isExpanded.toggle() }) {
                projectHeader
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var projectHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.textTertiary)
                .frame(width: 12)

            Image(systemName: "folder.fill")
                .font(.system(size: 11))
                .foregroundColor(.accentBlue)
            Text(projectGroup.projectName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textPrimary)
            Spacer()
            Text("\(projectGroup.worktreeGroups.reduce(0) { $0 + $1.results.count }) results")
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Worktree Result Section (List variant)

struct WorktreeResultSectionList: View {
    let worktreeGroup: WorktreeGroup
    let allResults: [SearchResult]
    let selectedResultId: String?
    let query: String
    let onSelect: (SearchResult) -> Void

    var body: some View {
        Section {
            ForEach(worktreeGroup.results) { result in
                let isSelected = result.id == selectedResultId
                GlobalSearchResultRow(
                    result: result,
                    isSelected: isSelected,
                    query: query,
                    onSelect: { onSelect(result) }
                )
                .id(result.id)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.visible)
            }
        } header: {
            worktreeHeader
        }
    }

    private var worktreeHeader: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
            Text(worktreeGroup.worktreeName)
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
            Spacer()
        }
        .padding(.leading, 14)
        .padding(.vertical, 2)
    }
}

// MARK: - Search Result Row

struct GlobalSearchResultRow: View {
    let result: SearchResult
    let isSelected: Bool
    let query: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(URL(fileURLWithPath: result.filePath).lastPathComponent)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)

                        if result.matchType == .filename {
                            Text("filename")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.accentBlue)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.accentBlue.opacity(0.12))
                                .cornerRadius(3)
                        }
                    }

                    if !result.matchingLine.isEmpty {
                        Text(highlightedText(result.matchingLine, query: query))
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Text(result.filePath)
                        .font(.system(size: 9))
                        .foregroundColor(.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.accentBlue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentBlue.opacity(0.12) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .id(result.id)
    }
}

private func highlightedText(_ text: String, query: String) -> AttributedString {
    var attributed = AttributedString(text)
    guard !query.isEmpty else { return attributed }

    let nsText = text as NSString
    var searchRange = NSRange(location: 0, length: nsText.length)

    while searchRange.location < nsText.length {
        let found = nsText.range(of: query, options: .caseInsensitive, range: searchRange)
        if found.location == NSNotFound { break }
        if let attrRange = Range(found, in: attributed) {
            attributed[attrRange].foregroundColor = .accentBlue
            attributed[attrRange].font = .system(size: 11, weight: .bold)
        }
        searchRange.location = found.location + found.length
        searchRange.length = nsText.length - searchRange.location
    }

    return attributed
}
