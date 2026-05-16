import SwiftUI

struct ImagePickerModalView: View {
    @Binding var isPresented: Bool
    var onSelect: (String) -> Void

    @State private var currentPath: String = NSHomeDirectory()
    @State private var entries: [FileEntry] = []
    @State private var pathHistory: [String] = []
    @State private var selectedPath: String?
    @State private var showHidden: Bool = false

    private let fileManager = FileManager.default
    private let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "ico", "svg", "gif", "webp", "bmp", "tiff", "tif"]

    var body: some View {
        ZStack(alignment: .center) {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                pathHeader
                Divider().overlay(Color.borderDefault)

                HSplitView {
                    fileList
                    previewPanel
                }

                Divider().overlay(Color.borderDefault)
                bottomBar
            }
            .frame(width: 640, height: 500)
            .background(Color.bgTertiary)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderLight, lineWidth: 1)
            )
        }
        .onAppear(perform: loadEntries)
        .onExitCommand { isPresented = false }
    }

    // MARK: - Path Header

    private var pathHeader: some View {
        HStack(spacing: 6) {
            Button(action: goBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(pathHistory.isEmpty ? .textTertiary : .textPrimary)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(pathHistory.isEmpty)

            Button(action: goToParent) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(currentPath == "/" ? .textTertiary : .textSecondary)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(currentPath == "/")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    let comps = URL(fileURLWithPath: currentPath).pathComponents
                    ForEach(Array(comps.enumerated()), id: \.offset) { i, comp in
                        if i > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7))
                                .foregroundColor(.textTertiary)
                        }
                        let partial = i == 0 ? "/" : comps[1...i].joined(separator: "/")
                        Button(action: { navigateTo(path: partial == "/" ? "/" : "/" + partial) }) {
                            Text(i == 0 ? "/" : comp)
                                .font(.system(size: 11))
                                .foregroundColor(i == comps.count - 1 ? .textPrimary : .accentBlue)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }

            Spacer()

            Button(action: { showHidden.toggle(); loadEntries() }) {
                Image(systemName: showHidden ? "eye.fill" : "eye.slash")
                    .font(.system(size: 11))
                    .foregroundColor(showHidden ? .accentBlue : .textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Show hidden files")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - File List

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if currentPath != "/" {
                    Button(action: goToParent) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 10))
                                .foregroundColor(.textTertiary)
                            Text("..")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                if entries.isEmpty {
                    VStack(spacing: 4) {
                        Spacer().frame(height: 40)
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.textTertiary)
                        Text("No image files")
                            .font(.system(size: 12))
                            .foregroundColor(.textTertiary)
                        Spacer().frame(height: 40)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(entries) { entry in
                        Button(action: {
                            if entry.isDirectory {
                                navigateTo(path: entry.path)
                            } else {
                                selectedPath = entry.path
                            }
                        }) {
                            HStack(spacing: 8) {
                                if entry.isDirectory {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.folderYellow)
                                } else {
                                    Image(systemName: "doc.richtext")
                                        .font(.system(size: 12))
                                        .foregroundColor(.accentBlue)
                                }

                                Text(entry.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                if selectedPath == entry.path {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.accentBlue)
                                } else if entry.isDirectory {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.textTertiary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selectedPath == entry.path ? Color.accentBlue.opacity(0.12) : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .layoutPriority(1)
    }

    // MARK: - Preview Panel

    private var previewPanel: some View {
        VStack(spacing: 8) {
            if let path = selectedPath, let nsImage = NSImage(contentsOfFile: path) {
                Spacer()

                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
                    .cornerRadius(8)

                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                if let size = nsImage.sizeInKB {
                    Text(size)
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                }

                let dimensions = "\(Int(nsImage.size.width)) × \(Int(nsImage.size.height))"
                Text(dimensions)
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)

                Spacer()
            } else {
                Spacer()
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundColor(.textTertiary)
                Text("Select an image")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
                Spacer()
            }
        }
        .frame(minWidth: 180)
        .background(Color.bgSecondary)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(action: { isPresented = false }) {
                Text("Cancel")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(selectedPath.flatMap { URL(fileURLWithPath: $0).lastPathComponent } ?? "")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 180)

            Button(action: {
                if let path = selectedPath {
                    onSelect(path)
                }
                isPresented = false
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .medium))
                    Text("Select Image")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selectedPath != nil ? Color.accentBlue : Color.bgHover)
                .foregroundColor(selectedPath != nil ? .white : .textTertiary)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut(.defaultAction)
            .disabled(selectedPath == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Navigation

    private func loadEntries() {
        var result: [FileEntry] = []
        guard let contents = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: currentPath),
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return }

        for url in contents {
            let name = url.lastPathComponent
            if !showHidden && name.hasPrefix(".") { continue }

            var isDir: ObjCBool = false
            let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
            guard exists else { continue }

            if isDir.boolValue {
                result.append(FileEntry(
                    name: name,
                    path: url.path,
                    isDirectory: true,
                    isHidden: name.hasPrefix(".")
                ))
            } else {
                let ext = url.pathExtension.lowercased()
                guard imageExtensions.contains(ext) else { continue }
                result.append(FileEntry(
                    name: name,
                    path: url.path,
                    isDirectory: false,
                    isHidden: name.hasPrefix(".")
                ))
            }
        }

        result.sort {
            if $0.isDirectory && !$1.isDirectory { return true }
            if !$0.isDirectory && $1.isDirectory { return false }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        entries = result
    }

    private func navigateTo(path: String) {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return }
        pathHistory.append(currentPath)
        currentPath = path
        selectedPath = nil
        loadEntries()
    }

    private func goToParent() {
        guard currentPath != "/" else { return }
        let parent = URL(fileURLWithPath: currentPath).deletingLastPathComponent().path
        pathHistory.append(currentPath)
        currentPath = parent
        selectedPath = nil
        loadEntries()
    }

    private func goBack() {
        guard let previous = pathHistory.popLast() else { return }
        currentPath = previous
        selectedPath = nil
        loadEntries()
    }
}

private extension NSImage {
    var sizeInKB: String? {
        guard let data = tiffRepresentation else { return nil }
        let kb = Double(data.count) / 1024.0
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024.0
        return String(format: "%.1f MB", mb)
    }
}
