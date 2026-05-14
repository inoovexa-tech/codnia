import SwiftUI

struct GlobalSearchView: View {
    @EnvironmentObject var searchVM: SearchService
    @EnvironmentObject var workspaceVM: WorkspaceService
    @EnvironmentObject var editorVM: EditorViewModel

    @State private var query: String = ""
    @State private var useRegex: Bool = false
    @State private var caseSensitive: Bool = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            filterBar
            results
        }
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textTertiary)
                .font(.system(size: 12))
            TextField("Search files...", text: $query)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 12))
                .foregroundColor(.textPrimary)
                .onSubmit(performSearch)
                .onChange(of: query) { newValue in
                    searchTask?.cancel()
                    if newValue.isEmpty {
                        searchVM.results = []
                    } else {
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            guard !Task.isCancelled else { return }
                            performSearch()
                        }
                    }
                }
            if !query.isEmpty {
                Button(action: { query = ""; searchVM.results = [] }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textTertiary)
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.bgSecondary)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                filterChip(label: "Regex", isOn: $useRegex)
                filterChip(label: "Case", isOn: $caseSensitive)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .background(Color.bgSecondary)
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
    private var results: some View {
        if searchVM.isSearching {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
                .progressViewStyle(CircularProgressViewStyle(tint: .textSecondary))
            Spacer()
        } else if searchVM.results.isEmpty && !query.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundColor(.textTertiary)
                Text("No matches")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(searchVM.results, id: \.0) { result in
                        SearchResultRow(
                            path: result.0,
                            line: result.1,
                            onSelect: { editorVM.openFile(result.0) }
                        )
                        Divider()
                            .background(Color.borderDefault)
                    }
                }
            }
            .background(Color.bgPrimary)
        }
    }

    private func performSearch() {
        guard let root = workspaceVM.activeProject?.path else { return }
        searchVM.searchContent(root: root, query: query, maxResults: 500, isRegex: useRegex, caseSensitive: caseSensitive)
    }
}

struct SearchResultRow: View {
    let path: String
    let line: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(line)
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
