import SwiftUI

struct AddProjectModalView: View {
    @Binding var isPresented: Bool
    var onSelect: (String) -> Void
    @State private var currentPath: String = NSHomeDirectory()
    @State private var directories: [FileEntry] = []
    @State private var pathHistory: [String] = []
    @State private var showHidden: Bool = false

    private let fileManager = FileManager.default

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                pathHeader
                Divider().overlay(Color.borderDefault)
                directoryList
                Divider().overlay(Color.borderDefault)
                bottomBar
            }
            .frame(width: 520, height: 500)
            .background(Color.bgTertiary)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderLight, lineWidth: 1)
            )
            .padding(.top, 60)
        }
        .onAppear(perform: loadDirectories)
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

            Button(action: { showHidden.toggle(); loadDirectories() }) {
                Image(systemName: showHidden ? "eye.fill" : "eye.slash")
                    .font(.system(size: 11))
                    .foregroundColor(showHidden ? .accentBlue : .textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Show hidden directories")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Directory List

    private var directoryList: some View {
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

                if directories.isEmpty {
                    VStack(spacing: 4) {
                        Spacer().frame(height: 60)
                        Image(systemName: "folder")
                            .font(.system(size: 24))
                            .foregroundColor(.textTertiary)
                        Text("No subdirectories")
                            .font(.system(size: 12))
                            .foregroundColor(.textTertiary)
                        Spacer().frame(height: 60)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(directories) { entry in
                        Button(action: { navigateTo(path: entry.path) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.folderYellow)

                                Text(entry.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.textTertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(entry.path == currentPath ? Color.accentBlue.opacity(0.1) : Color.clear)
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
                Text(currentPath)
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: 180)

            Button(action: {
                onSelect(currentPath)
                isPresented = false
            }) {
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
    }

    // MARK: - Navigation

    private func loadDirectories() {
        var entries: [FileEntry] = []
        guard let contents = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: currentPath),
            includingPropertiesForKeys: [.isDirectoryKey, .isReadableKey]
        ) else { return }

        for url in contents {
            let name = url.lastPathComponent
            if !showHidden && name.hasPrefix(".") { continue }

            var isDir: ObjCBool = false
            let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
            guard exists && isDir.boolValue else { continue }

            entries.append(FileEntry(
                name: name,
                path: url.path,
                isDirectory: true,
                isHidden: name.hasPrefix(".")
            ))
        }

        entries.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        directories = entries
    }

    private func navigateTo(path: String) {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return }
        pathHistory.append(currentPath)
        currentPath = path
        loadDirectories()
    }

    private func goToParent() {
        guard currentPath != "/" else { return }
        let parent = URL(fileURLWithPath: currentPath).deletingLastPathComponent().path
        pathHistory.append(currentPath)
        currentPath = parent
        loadDirectories()
    }

    private func goBack() {
        guard let previous = pathHistory.popLast() else { return }
        currentPath = previous
        loadDirectories()
    }
}
