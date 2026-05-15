import SwiftUI
import UniformTypeIdentifiers

enum FileTreeHeaderAction: Equatable {
    case newFile
    case newFolder
    case collapseAll
}

struct FileTreeView: View {
    let entries: [FileEntry]
    let onSelect: (String) -> Void
    let onRefresh: () -> Void
    @Binding var selectedPath: String?
    let activeFilePath: String?
    let rootPath: String
    let modifiedPaths: Set<String>
    @Binding var headerAction: FileTreeHeaderAction?

    @State private var expandedPaths = Set<String>()
    @State private var inlineEdit: InlineEdit?
    @State private var focusPath: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(entries) { entry in
                        TreeNode(
                            entry: entry,
                            depth: 0,
                            expandedPaths: $expandedPaths,
                            inlineEdit: $inlineEdit,
                            selectedPath: $selectedPath,
                            focusPath: $focusPath,
                            modifiedPaths: modifiedPaths,
                            rootPath: rootPath,
                            onSelect: onSelect,
                            onRefresh: onRefresh
                        )
                        .id(entry.path)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                    if let edit = inlineEdit, edit.type != .rename, edit.parentPath == rootPath {
                        HStack(spacing: 4) {
                            Spacer().frame(width: 12)
                            Image(systemName: edit.type == .newDirectory ? "folder" : "doc")
                                .font(.system(size: 13))
                                .foregroundColor(edit.type == .newDirectory ? .folderYellow : .textSecondary)
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
                                onCancel: { inlineEdit = nil }
                            )
                        }
                        .padding(.leading, CGFloat(8))
                        .padding(.vertical, 2)
                        .frame(height: 22)
                    }
            }
            .onChange(of: selectedPath) { newPath in
                guard let path = newPath else { return }
                expandAncestors(of: path)
                withAnimation(.none) {
                    proxy.scrollTo(path, anchor: .center)
                }
            }
            .onChange(of: activeFilePath) { newPath in
                guard let path = newPath, path != selectedPath else { return }
                selectedPath = path
            }
            .onChange(of: headerAction) { action in
                guard let action = action else { return }
                handleHeaderAction(action)
                headerAction = nil
            }
        }
        .focusable()
        .onMoveCommand { direction in
            handleMoveCommand(direction)
        }
    }

    private func expandAncestors(of path: String) {
        var current = URL(fileURLWithPath: path).deletingLastPathComponent()
        let root = URL(fileURLWithPath: rootPath).standardized
        while current.path != "/" && current.path != root.path {
            expandedPaths.insert(current.path)
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }
    }

    private func handleHeaderAction(_ action: FileTreeHeaderAction) {
        switch action {
        case .newFile:
            guard !rootPath.isEmpty else { return }
            inlineEdit = InlineEdit(type: .newFile, parentPath: rootPath)
        case .newFolder:
            guard !rootPath.isEmpty else { return }
            inlineEdit = InlineEdit(type: .newDirectory, parentPath: rootPath)
        case .collapseAll:
            expandedPaths.removeAll()
        }
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard let current = selectedPath ?? focusPath else {
            if let first = entries.first {
                selectedPath = first.path
                focusPath = first.path
            }
            return
        }

        let flat = flattenVisible(entries)
        guard let index = flat.firstIndex(of: current) else { return }

        let targetIndex: Int
        switch direction {
        case .down:
            targetIndex = index + 1
        case .up:
            targetIndex = index - 1
        case .right:
            if let entry = findEntry(for: current, in: entries), entry.isDirectory {
                if !expandedPaths.contains(entry.path) {
                    expandAncestors(of: entry.path)
                    expandedPaths.insert(entry.path)
                }
                focusPath = current
            }
            return
        case .left:
            let url = URL(fileURLWithPath: current)
            let parent = url.deletingLastPathComponent()
            if parent.path != "/" {
                let parentURL = URL(fileURLWithPath: rootPath).standardized
                if parent.path != parentURL.path {
                    selectedPath = parent.path
                    focusPath = parent.path
                }
            }
            return
        default:
            return
        }

        guard flat.indices.contains(targetIndex) else { return }
        let target = flat[targetIndex]
        if let entry = findEntry(for: target, in: entries), !entry.isDirectory {
            selectedPath = target
        }
        focusPath = target
    }

    private func flattenVisible(_ entries: [FileEntry]) -> [String] {
        var result: [String] = []
        for entry in entries {
            result.append(entry.path)
            if entry.isDirectory && expandedPaths.contains(entry.path) {
                let children = FileSystemService.shared.listDirectory(path: entry.path)
                result.append(contentsOf: flattenVisible(children))
            }
        }
        return result
    }

    private func findEntry(for path: String, in entries: [FileEntry]) -> FileEntry? {
        for entry in entries {
            if entry.path == path { return entry }
            if let found = findEntry(for: path, in: entry.children ?? []) { return found }
        }
        return nil
    }
}

struct TreeNode: View {
    let entry: FileEntry
    let depth: Int
    @Binding var expandedPaths: Set<String>
    @Binding var inlineEdit: InlineEdit?
    @Binding var selectedPath: String?
    @Binding var focusPath: String?
    let modifiedPaths: Set<String>
    let rootPath: String
    let onSelect: (String) -> Void
    let onRefresh: () -> Void

    @State private var children: [FileEntry] = []
    @State private var loaded = false
    @State private var hovered = false
    @State private var isDropTarget = false

    private var isExpanded: Bool { expandedPaths.contains(entry.path) }
    private var isSelected: Bool {
        selectedPath == entry.path && !entry.isDirectory
    }
    private var isFocused: Bool { focusPath == entry.path }
    private var isEditing: Bool { inlineEdit?.path == entry.path }
    private var isModified: Bool { modifiedPaths.contains(entry.path) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                if entry.isDirectory {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.textTertiary)
                        .frame(width: 12, height: 16)
                        .onTapGesture { toggleExpand() }
                } else {
                    Spacer().frame(width: 12)
                }

                if entry.isDirectory {
                    Image(systemName: isExpanded ? "folder" : "folder.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.folderYellow)
                } else {
                    Image(systemName: "doc")
                        .font(.system(size: 13))
                        .foregroundColor(fileIconColor)
                }

                if isEditing, let edit = inlineEdit {
                    InlineTextField(
                        defaultValue: edit.originalName,
                        onConfirm: { name in
                            if !name.isEmpty && name != edit.originalName, let oldPath = edit.path {
                                let newPath = "\(edit.parentPath)/\(name)"
                                try? FileSystemService.shared.rename(oldPath: oldPath, newPath: newPath)
                            }
                            inlineEdit = nil
                            onRefresh()
                        },
                        onCancel: { inlineEdit = nil }
                    )
                } else {
                    HStack(spacing: 4) {
                        if isModified {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.accentOrange)
                        }
                        Text(entry.name)
                            .font(.system(size: 12))
                            .foregroundColor(isSelected ? .white : entry.isDirectory ? .textPrimary : .textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.leading, CGFloat(8 + depth * 16))
            .padding(.vertical, 2)
            .frame(height: 22)
            .background(backgroundView)
            .overlay(
                Group {
                    if isDropTarget {
                        Rectangle()
                            .fill(Color.accentBlue)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, CGFloat(8 + depth * 16))
                    }
                },
                alignment: .bottom
            )
            .opacity(entry.isHidden ? 0.5 : 1)
            .onHover { hovered = $0 }
            .onChange(of: isExpanded) { expanded in
                if expanded && !loaded {
                    children = FileSystemService.shared.listDirectory(path: entry.path)
                    loaded = true
                }
            }
            .onDrag { NSItemProvider(object: entry.path as NSString) }
            .onDrop(of: [.text], isTargeted: $isDropTarget) { providers in
                handleDrop(providers: providers)
            }
            .onTapGesture {
                if entry.isDirectory {
                    toggleExpand()
                } else {
                    selectedPath = entry.path
                    onSelect(entry.path)
                }
            }
            .contextMenu { contextMenuContent }

            if isExpanded && loaded {
                ForEach(children) { child in
                    TreeNode(
                        entry: child,
                        depth: depth + 1,
                        expandedPaths: $expandedPaths,
                        inlineEdit: $inlineEdit,
                        selectedPath: $selectedPath,
                        focusPath: $focusPath,
                        modifiedPaths: modifiedPaths,
                        rootPath: rootPath,
                        onSelect: onSelect,
                        onRefresh: onRefresh
                    )
                }

                if let edit = inlineEdit, edit.type != .rename, edit.parentPath == entry.path {
                    HStack(spacing: 4) {
                        Spacer().frame(width: 12)
                        Image(systemName: edit.type == .newDirectory ? "folder" : "doc")
                            .font(.system(size: 13))
                            .foregroundColor(edit.type == .newDirectory ? .folderYellow : .textSecondary)
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
                            onCancel: { inlineEdit = nil }
                        )
                    }
                    .padding(.leading, CGFloat(8 + (depth + 1) * 16))
                    .padding(.vertical, 2)
                    .frame(height: 22)
                }
            }
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isSelected {
            Color.selectionBg
        } else if isDropTarget {
            Color.accentBlue.opacity(0.15)
        } else if hovered {
            Color.bgHover
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button("Reveal in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: entry.path)])
        }

        if entry.isDirectory {
            Button("New File") {
                let parentPath = entry.path
                if !expandedPaths.contains(entry.path) {
                    expandedPaths.insert(entry.path)
                }
                inlineEdit = InlineEdit(type: .newFile, parentPath: parentPath)
            }
            Button("New Folder") {
                let parentPath = entry.path
                if !expandedPaths.contains(entry.path) {
                    expandedPaths.insert(entry.path)
                }
                inlineEdit = InlineEdit(type: .newDirectory, parentPath: parentPath)
            }
        } else {
            Button("New File") {
                let parentPath = URL(fileURLWithPath: entry.path).deletingLastPathComponent().path
                expandedPaths.insert(parentPath)
                inlineEdit = InlineEdit(type: .newFile, parentPath: parentPath)
            }
            Button("New Folder") {
                let parentPath = URL(fileURLWithPath: entry.path).deletingLastPathComponent().path
                expandedPaths.insert(parentPath)
                inlineEdit = InlineEdit(type: .newDirectory, parentPath: parentPath)
            }
        }

        Divider()

        Button("Duplicate") {
            _ = try? FileSystemService.shared.duplicate(path: entry.path)
            onRefresh()
        }
        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.path, forType: .string)
        }

        let relativePath = computeRelativePath()
        if !relativePath.isEmpty {
            Button("Copy Relative Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(relativePath, forType: .string)
            }
        }

        Divider()

        Button("Rename") {
            inlineEdit = InlineEdit(
                type: .rename,
                path: entry.path,
                originalName: entry.name,
                parentPath: URL(fileURLWithPath: entry.path).deletingLastPathComponent().path
            )
        }
        Button("Delete") {
            try? FileSystemService.shared.delete(path: entry.path)
            onRefresh()
        }
    }

    private func computeRelativePath() -> String {
        guard !rootPath.isEmpty else { return "" }
        let root = URL(fileURLWithPath: rootPath).standardized.path
        let filePath = URL(fileURLWithPath: entry.path).standardized.path
        guard filePath.hasPrefix(root) else { return "" }
        return String(filePath.dropFirst(root.count + 1))
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard entry.isDirectory else { return false }
        let entryPath = entry.path

        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                let sourcePath: String
                if let str = item as? String {
                    sourcePath = str
                } else if let data = item as? Data, let str = String(data: data, encoding: .utf8) {
                    sourcePath = str
                } else {
                    return
                }

                let sourceURL = URL(fileURLWithPath: sourcePath)
                let fileName = sourceURL.lastPathComponent
                let destination = URL(fileURLWithPath: entryPath).appendingPathComponent(fileName)
                guard sourceURL.path != destination.path else { return }
                try? FileManager.default.moveItem(at: sourceURL, to: destination)
                DispatchQueue.main.async {
                    onRefresh()
                }
            }
        }
        return true
    }

    private func toggleExpand() {
        guard entry.isDirectory else { return }
        if isExpanded {
            expandedPaths.remove(entry.path)
            loaded = false
            children = []
        } else {
            expandedPaths.insert(entry.path)
            children = FileSystemService.shared.listDirectory(path: entry.path)
            loaded = true
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
}

struct InlineTextField: View {
    let defaultValue: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var value = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $value)
            .font(.system(size: 12))
            .foregroundColor(.textPrimary)
            .textFieldStyle(PlainTextFieldStyle())
            .background(Color.bgTertiary)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.accentBlue, lineWidth: 1)
            )
            .frame(height: 18)
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
