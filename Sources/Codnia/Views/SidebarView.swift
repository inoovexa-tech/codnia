import SwiftUI
import AppKit

struct SidebarView: View {
    @Binding var expanded: Bool
    @EnvironmentObject var workspaceVM: WorkspaceService
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var settings: SettingsService

    static var settingsWindowController: NSWindowController?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 4) {
                    if expanded {
                        SidebarExpandedProjectsList()
                    } else {
                        SidebarCollapsedProjectsList()
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, expanded ? 8 : 4)
            }

            Spacer()

            if expanded {
                HStack(spacing: 4) {
                    Button(action: { openSettingsWindow() }) {
                        Image(systemName: "gear")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 36, height: 36)
                    .background(Color.clear)
                    .cornerRadius(8)

                    Spacer()

                    Button(action: { expanded.toggle() }) {
                        Image(systemName: expanded ? "sidebar.left" : "sidebar.right")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 36, height: 36)
                    .background(Color.clear)
                    .cornerRadius(8)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .foregroundColor(.textPrimary)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.borderDefault),
                    alignment: .top
                )
            } else {
                VStack(spacing: 4) {
                    Button(action: { openSettingsWindow() }) {
                        Image(systemName: "gear")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 36, height: 36)
                    .background(Color.clear)
                    .cornerRadius(8)

                    Button(action: { expanded.toggle() }) {
                        Image(systemName: expanded ? "sidebar.left" : "sidebar.right")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 36, height: 36)
                    .background(Color.clear)
                    .cornerRadius(8)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .foregroundColor(.textPrimary)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.borderDefault),
                    alignment: .top
                )
            }
        }
        .background(Color.black)
    }

    private func openSettingsWindow() {
        if let existingController = Self.settingsWindowController,
           let window = existingController.window,
           window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(settings)
            .frame(minWidth: 700, minHeight: 540)

        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 700, height: 540)
        hostingView.wantsLayer = true

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 540),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = hostingView
        window.minSize = NSSize(width: 700, height: 540)
        window.backgroundColor = NSColor(Color.bgPrimary)
        window.center()

        let controller = NSWindowController(window: window)
        Self.settingsWindowController = controller
        controller.showWindow(nil)
    }
}

struct SidebarExpandedProjectsList: View {
    @EnvironmentObject var workspaceVM: WorkspaceService

    var body: some View {
        ForEach(workspaceVM.projects) { project in
            ProjectRowExpanded(project: project)
        }

        Button(action: { addProject() }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14))
                Text("Add Project")
                    .font(.system(size: 12))
            }
            .frame(maxWidth: .infinity, minHeight: 32)
            .foregroundColor(.textSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.borderLight, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 4)
    }

    private func addProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            workspaceVM.addProject(path: url.path)
        }
    }
}

struct SidebarCollapsedProjectsList: View {
    @EnvironmentObject var workspaceVM: WorkspaceService

    var body: some View {
        ForEach(workspaceVM.projects) { project in
            ProjectRowCollapsed(project: project)
        }

        Button(action: { addProject() }) {
            Image(systemName: "plus")
                .font(.system(size: 14))
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 36, height: 36)
        .background(Color.bgTertiary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.borderLight, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
        .padding(.top, 4)
    }

    private func addProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            workspaceVM.addProject(path: url.path)
        }
    }
}

struct ProjectRowExpanded: View {
    let project: Project
    @EnvironmentObject var workspaceVM: WorkspaceService
    @State private var showRenameModal = false
    @State private var renameName: String = ""
    @State private var renameDirectory = false

    var isActive: Bool {
        workspaceVM.activeProject?.id == project.id
    }

    private var initials: String {
        project.name
            .split { $0.isWhitespace || $0 == "_" || $0 == "-" }
            .prefix(2)
            .compactMap { $0.first?.uppercased() }
            .joined()
    }

    var body: some View {
        Button(action: {
            workspaceVM.setActiveProject(id: project.id)
        }) {
            HStack(spacing: 8) {
                Text(initials)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(isActive ? Color.accentBlue : Color.bgHover)
                    .foregroundColor(.white)
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if !branchText.isEmpty {
                        HStack(spacing: 4) {
                            Text(branchText)
                                .font(.system(size: 10))
                                .foregroundColor(.textSecondary)

                            Spacer()

                            changesBadge
                                .font(.system(size: 10))
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(isActive ? Color.bgTertiary : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button("Rename") {
                renameName = project.name
                renameDirectory = false
                showRenameModal = true
            }
            Button("Remove") { workspaceVM.removeProject(id: project.id) }
        }
        .sheet(isPresented: $showRenameModal) {
            VStack(spacing: 16) {
                Text("Rename Project")
                    .font(.headline)

                TextField("Project Name", text: $renameName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 250)

                Toggle("Rename directory as well", isOn: $renameDirectory)

                HStack(spacing: 12) {
                    Button("Cancel") { showRenameModal = false }
                        .keyboardShortcut(.cancelAction)
                    Button("Rename") {
                        if !renameName.isEmpty {
                            workspaceVM.renameProject(id: project.id, newName: renameName, renameDirectory: renameDirectory)
                        }
                        showRenameModal = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 300, height: 180)
        }
    }

    private var branchText: String {
        workspaceVM.branches[project.id] ?? ""
    }

    @ViewBuilder
    private var changesBadge: some View {
        if let changes = workspaceVM.changesCount[project.id], changes.added > 0 || changes.deleted > 0 {
            HStack(spacing: 2) {
                Text("+\(changes.added)")
                    .foregroundColor(.green)
                Text("-\(changes.deleted)")
                    .foregroundColor(.red)
            }
        }
    }
}

struct ProjectRowCollapsed: View {
    let project: Project
    @EnvironmentObject var workspaceVM: WorkspaceService

    var isActive: Bool {
        workspaceVM.activeProject?.id == project.id
    }

    private var initials: String {
        project.name
            .split { $0.isWhitespace || $0 == "_" || $0 == "-" }
            .prefix(2)
            .compactMap { $0.first?.uppercased() }
            .joined()
    }

    var body: some View {
        Button(action: {
            workspaceVM.setActiveProject(id: project.id)
        }) {
            Text(initials)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(isActive ? Color.accentBlue : Color.bgTertiary)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .help(project.name)
    }
}
