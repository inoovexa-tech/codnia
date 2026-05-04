import SwiftUI

struct GlobalSearchView: View {
    @EnvironmentObject var searchVM: SearchService
    @EnvironmentObject var workspaceVM: WorkspaceService
    @EnvironmentObject var editorVM: EditorViewModel

    @State private var query: String = ""
    @State private var useRegex: Bool = false
    @State private var caseSensitive: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Search input
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.textTertiary)

                TextField("Search", text: $query)
                    .font(.system(size: 13))
                    .foregroundColor(.textPrimary)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }

                if !query.isEmpty {
                    Button(action: {
                        query = ""
                        searchVM.results = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.textTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.bgTertiary)
            .cornerRadius(6)
            .padding(8)

            // Options
            HStack(spacing: 12) {
                Toggle("Regex", isOn: $useRegex)
                    .toggleStyle(CheckboxToggleStyle())
                Toggle("Case", isOn: $caseSensitive)
                    .toggleStyle(CheckboxToggleStyle())
                Spacer()
            }
            .font(.system(size: 11))
            .foregroundColor(.textSecondary)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            Divider()
                .background(Color.borderDefault)

            // Results
            if searchVM.isSearching {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: .textSecondary))
                Spacer()
            } else if searchVM.results.isEmpty && !query.isEmpty {
                Spacer()
                Text("No results found")
                    .font(.system(size: 13))
                    .foregroundColor(.textTertiary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(searchVM.results, id: \.0) { result in
                            SearchResultRow(
                                path: result.0,
                                line: result.1,
                                onSelect: {
                                    editorVM.openFile(result.0)
                                }
                            )
                        }
                    }
                }
            }
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

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: 12))
                .foregroundColor(configuration.isOn ? .accentBlue : .textTertiary)
            configuration.label
        }
        .onTapGesture {
            configuration.isOn.toggle()
        }
    }
}
