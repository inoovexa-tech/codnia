import SwiftUI

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
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    searchHeader
                    modeBar
                }
                .background(Color.bgSecondary)
                .cornerRadius(12)

                if !query.isEmpty {
                    resultsList
                        .frame(maxHeight: 440)
                        .background(Color.bgPrimary)
                }
            }
            .frame(width: 640)
            .background(Color.bgPrimary)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderLight, lineWidth: 1)
            )
            .padding(.top, 60)
        }
        .onAppear {
            isSearchFieldFocused = true
        }
        .onExitCommand {
            if query.isEmpty {
                isPresented = false
            } else {
                query = ""
                searchVM.globalResults = []
            }
        }
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
                    } else {
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            guard !Task.isCancelled else { return }
                            performSearch()
                        }
                    }
                }

            if !query.isEmpty {
                Button(action: { query = ""; searchVM.globalResults = [] }) {
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
            .background(isOn.wrappedValue ? Color.accentBlue.opacity(0.15) : Color.bgTertiary)
            .foregroundColor(isOn.wrappedValue ? .accentBlue : .textSecondary)
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsList: some View {
        if searchVM.isGlobalSearching {
            VStack(spacing: 8) {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: .textSecondary))
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if searchVM.globalResults.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundColor(.textTertiary)
                Text("No matches")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            let groups = buildGroups(from: searchVM.globalResults)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(groups) { projectGroup in
                        ProjectResultSection(
                            projectGroup: projectGroup,
                            onSelect: { result in
                                selectResult(result)
                            }
                        )
                    }
                }
            }
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
        editorVM.openFileInWorktree(
            path: result.filePath,
            projectId: result.projectId,
            worktreeId: result.worktreeId
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

// MARK: - Project Result Section

struct ProjectResultSection: View {
    let projectGroup: ProjectGroup
    let onSelect: (SearchResult) -> Void

    var body: some View {
        VStack(spacing: 0) {
            projectHeader
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

            ForEach(projectGroup.worktreeGroups) { worktreeGroup in
                WorktreeResultSection(
                    worktreeGroup: worktreeGroup,
                    projectName: projectGroup.projectName,
                    onSelect: onSelect
                )
            }
        }
    }

    private var projectHeader: some View {
        HStack(spacing: 6) {
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
    }
}

// MARK: - Worktree Result Section

struct WorktreeResultSection: View {
    let worktreeGroup: WorktreeGroup
    let projectName: String
    let onSelect: (SearchResult) -> Void

    var body: some View {
        VStack(spacing: 0) {
            worktreeHeader
                .padding(.leading, 28)
                .padding(.trailing, 14)
                .padding(.vertical, 3)

            ForEach(worktreeGroup.results) { result in
                GlobalSearchResultRow(
                    result: result,
                    onSelect: { onSelect(result) }
                )
                Divider()
                    .background(Color.borderDefault)
            }
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
    }
}

// MARK: - Search Result Row

struct GlobalSearchResultRow: View {
    let result: SearchResult
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
                        Text(result.matchingLine)
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
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
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
