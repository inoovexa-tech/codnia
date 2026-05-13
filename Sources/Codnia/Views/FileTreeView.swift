import SwiftUI

struct FileTreeView: View {
    let entries: [FileEntry]
    let onSelect: (String) -> Void
    let onRefresh: () -> Void
    @State private var expandedPaths = Set<String>()
    @State private var inlineEdit: InlineEdit? = nil

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(entries) { entry in
                    TreeNode(
                        entry: entry,
                        depth: 0,
                        expandedPaths: $expandedPaths,
                        inlineEdit: $inlineEdit,
                        onSelect: onSelect,
                        onRefresh: onRefresh
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct TreeNode: View {
    let entry: FileEntry
    let depth: Int
    @Binding var expandedPaths: Set<String>
    @Binding var inlineEdit: InlineEdit?
    let onSelect: (String) -> Void
    let onRefresh: () -> Void

    @State private var children: [FileEntry] = []
    @State private var loaded = false
    @State private var hovered = false

    private var isExpanded: Bool {
        expandedPaths.contains(entry.path)
    }

    private var isEditing: Bool {
        inlineEdit?.path == entry.path
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                if entry.isDirectory {
                    Button(action: toggleExpand) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 16, height: 16)
                } else {
                    Spacer().frame(width: 16)
                }

                if entry.isDirectory {
                    Image(systemName: isExpanded ? "folder" : "folder.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.folderYellow)
                } else {
                    Image(systemName: "doc")
                        .font(.system(size: 14))
                        .foregroundColor(fileIconColor)
                }

                if isEditing, let edit = inlineEdit {
                    InlineTextField(
                        defaultValue: edit.originalName,
                        onConfirm: { name in
                            if !name.isEmpty && name != edit.originalName {
                                let newPath = "\(edit.parentPath)/\(name)"
                                if let oldPath = edit.path {
                                    try? FileSystemService.shared.rename(oldPath: oldPath, newPath: newPath)
                                }
                            }
                            inlineEdit = nil
                            onRefresh()
                        },
                        onCancel: {
                            inlineEdit = nil
                        }
                    )
                } else {
                    Text(entry.name)
                        .font(.system(size: 13))
                        .foregroundColor(entry.isDirectory ? .textPrimary : .textSecondary)
                        .lineLimit(1)
                }

                if entry.isDirectory && !isEditing {
                    Spacer()
                    HStack(spacing: 2) {
                        Button(action: {
                            inlineEdit = InlineEdit(type: .newFile, parentPath: entry.path)
                        }) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 20, height: 20)

                        Button(action: {
                            inlineEdit = InlineEdit(type: .newDirectory, parentPath: entry.path)
                        }) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 20, height: 20)
                    }
                    .opacity(hovered ? 1 : 0)
                }
            }
            .padding(.leading, CGFloat(8 + depth * 16))
            .padding(.vertical, 2)
            .frame(height: 24)
            .background(hovered ? Color.bgHover : Color.clear)
            .opacity(entry.isHidden ? 0.5 : 1.0)
            .onHover { hovering in
                hovered = hovering
            }
            .onChange(of: isExpanded) { expanded in
                if expanded && !loaded {
                    children = FileSystemService.shared.listDirectory(path: entry.path)
                    loaded = true
                }
            }
            .onDrag {
                NSItemProvider(object: entry.path as NSString)
            }
            .onTapGesture {
                if entry.isDirectory {
                    toggleExpand()
                } else {
                    onSelect(entry.path)
                }
            }
            .contextMenu {
                Button("Open in Finder") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: entry.isDirectory ? entry.path : URL(fileURLWithPath: entry.path).deletingLastPathComponent().path))
                }
                Button("New File") {
                    let parentPath = entry.isDirectory ? entry.path : (URL(fileURLWithPath: entry.path).deletingLastPathComponent().path)
                    if !entry.isDirectory {
                        expandedPaths.insert(URL(fileURLWithPath: parentPath).path)
                    }
                    inlineEdit = InlineEdit(type: .newFile, parentPath: parentPath)
                }
                Button("New Folder") {
                    let parentPath = entry.isDirectory ? entry.path : (URL(fileURLWithPath: entry.path).deletingLastPathComponent().path)
                    if !entry.isDirectory {
                        expandedPaths.insert(URL(fileURLWithPath: parentPath).path)
                    }
                    inlineEdit = InlineEdit(type: .newDirectory, parentPath: parentPath)
                }
                Divider()
                Button("Rename") {
                    inlineEdit = InlineEdit(type: .rename, path: entry.path, originalName: entry.name, parentPath: URL(fileURLWithPath: entry.path).deletingLastPathComponent().path)
                }
                Button("Delete") {
                    try? FileSystemService.shared.delete(path: entry.path)
                    onRefresh()
                }
            }

            if isExpanded && loaded {
                ForEach(children) { child in
                    TreeNode(
                        entry: child,
                        depth: depth + 1,
                        expandedPaths: $expandedPaths,
                        inlineEdit: $inlineEdit,
                        onSelect: onSelect,
                        onRefresh: onRefresh
                    )
                }

                // Inline new file/folder row
                if let edit = inlineEdit, edit.type != .rename, edit.parentPath == entry.path {
                    HStack(spacing: 4) {
                        Spacer().frame(width: 16)
                        if edit.type == .newDirectory {
                            Image(systemName: "folder")
                                .font(.system(size: 14))
                                .foregroundColor(.folderYellow)
                        } else {
                            Image(systemName: "doc")
                                .font(.system(size: 14))
                                .foregroundColor(.textSecondary)
                        }
                        InlineTextField(
                            defaultValue: "",
                            onConfirm: { name in
                                let newPath = "\(edit.parentPath)/\(name)"
                                if edit.type == .newFile {
                                    try? FileSystemService.shared.createFile(path: newPath)
                                } else {
                                    try? FileSystemService.shared.createDirectory(path: newPath)
                                }
                                inlineEdit = nil
                                onRefresh()
                            },
                            onCancel: {
                                inlineEdit = nil
                            }
                        )
                    }
                    .padding(.leading, CGFloat(8 + (depth + 1) * 16))
                    .padding(.vertical, 2)
                    .frame(height: 24)
                }
            }
        }
    }

    private var fileIconColor: Color {
        let ext = URL(fileURLWithPath: entry.name).pathExtension.lowercased()
        switch ext {
        case "rs": return .fileRust
        case "ts", "tsx": return .fileTs
        case "js", "jsx": return .fileJs
        case "json": return .fileJson
        case "html", "htm": return .fileHtml
        case "css", "scss": return .fileCss
        case "md": return .fileMd
        default: return .fileDefault
        }
    }

    private func toggleExpand() {
        guard entry.isDirectory else { return }
        if expandedPaths.contains(entry.path) {
            expandedPaths.remove(entry.path)
            // Reset loaded state so children reload on next expand
            loaded = false
            children = []
        } else {
            expandedPaths.insert(entry.path)
            children = FileSystemService.shared.listDirectory(path: entry.path)
            loaded = true
        }
    }
}

struct InlineTextField: View {
    let defaultValue: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var value: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $value)
            .font(.system(size: 13))
            .foregroundColor(.textPrimary)
            .textFieldStyle(PlainTextFieldStyle())
            .background(Color.bgTertiary)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.accentBlue, lineWidth: 1)
            )
            .frame(height: 20)
            .focused($focused)
            .onAppear {
                value = defaultValue
                focused = true
            }
            .onSubmit {
                onConfirm(value)
            }
            .onExitCommand {
                onCancel()
            }
    }
}

struct InlineEdit: Equatable {
    enum EditType { case rename, newFile, newDirectory }
    let type: EditType
    let path: String?
    let originalName: String
    let parentPath: String

    init(type: EditType, path: String? = nil, originalName: String = "", parentPath: String) {
        self.type = type
        self.path = path
        self.originalName = originalName
        self.parentPath = parentPath
    }

    static func == (lhs: InlineEdit, rhs: InlineEdit) -> Bool {
        lhs.path == rhs.path && lhs.type == rhs.type && lhs.parentPath == rhs.parentPath
    }
}
