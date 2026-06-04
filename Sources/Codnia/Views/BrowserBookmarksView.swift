import SwiftUI

struct BrowserBookmarksView: View {
    @EnvironmentObject var appState: AppState
    @State private var editingBookmark: BrowserBookmark?
    @State private var editTitle: String = ""

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            content
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            TextField("Search bookmarks", text: $appState.bookmarkService.searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.bgTertiary)
                .cornerRadius(3)

            Text("\(appState.bookmarkService.bookmarks.count)")
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
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
        if appState.bookmarkService.bookmarks.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(appState.bookmarkService.groupedByFolder, id: \.folder) { group in
                        sectionHeader(group.folder)
                        ForEach(group.items) { bookmark in
                            BookmarkRow(
                                bookmark: bookmark,
                                onOpen: { openBookmark(bookmark) },
                                onEdit: { startEdit(bookmark) },
                                onDelete: { appState.bookmarkService.remove(bookmark) }
                            )
                        }
                    }
                }
            }
            .background(Color.bgPrimary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "star")
                .font(.system(size: 20))
                .foregroundColor(.textTertiary)
            Text("No bookmarks yet")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
            Text("Click the star in the toolbar to save the current page")
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.bgTertiary.opacity(0.3))
    }

    private func openBookmark(_ bookmark: BrowserBookmark) {
        appState.openURL(bookmark.url, in: .tab)
    }

    private func startEdit(_ bookmark: BrowserBookmark) {
        editingBookmark = bookmark
        editTitle = bookmark.title
    }
}

struct BookmarkRow: View {
    let bookmark: BrowserBookmark
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.system(size: 10))
                .foregroundColor(.accentBlue)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(bookmark.title)
                    .font(.system(size: 10))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text(bookmark.host)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            Menu {
                Button("Open in Tab") { onOpen() }
                Button("Open in Left Panel") { /* TODO */ }
                Button("Open in Right Panel") { /* TODO */ }
                Divider()
                Button("Rename…", action: onEdit)
                Button("Copy URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(bookmark.url, forType: .string)
                }
                Divider()
                Button("Delete", role: .destructive, action: onDelete)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onOpen() }
    }
}
