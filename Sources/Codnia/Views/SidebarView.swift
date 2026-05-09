import SwiftUI
import AppKit

struct SidebarView: View {
    @Binding var expanded: Bool
    @EnvironmentObject var workspaceVM: WorkspaceService
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var terminalVM: TerminalViewModel
    @EnvironmentObject var settings: SettingsService

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

            SidebarBottomBar(expanded: $expanded, onOpenSettings: openSettingsWindow)
        }
        .background(Color.clear)
    }

    private func openSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

struct SidebarExpandedProjectsList: View {
    @EnvironmentObject var workspaceVM: WorkspaceService

    var body: some View {
        ForEach(workspaceVM.projects) { project in
            ProjectRowExpanded(projectId: project.id)
                .id("\(project.id)-wt-\(project.worktrees.count)")
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
            .contentShape(Rectangle())
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
            ProjectRowCollapsed(projectId: project.id)
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
        .contentShape(Rectangle())
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
    let projectId: String
    @EnvironmentObject var workspaceVM: WorkspaceService
    @EnvironmentObject var terminalVM: TerminalViewModel
    @State private var showRenameModal = false
    @State private var renameName: String = ""
    @State private var renameDirectory = false
    @State private var showIconPicker = false
    @State private var showAddWorktree = false
    @State private var showWorktreeContextMenu = false
    @State private var contextMenuWorktree: Worktree?
    @State private var isWorktreesExpanded = false

    private var project: Project? {
        workspaceVM.projects.first { $0.id == projectId }
    }

    var isActive: Bool {
        workspaceVM.activeProject?.id == projectId
    }

    private var activeWorktree: Worktree? {
        project?.activeWorktree
    }

    private var initials: String {
        guard let project = project else { return "" }
        return project.name
            .split { $0.isWhitespace || $0 == "_" || $0 == "-" }
            .prefix(2)
            .compactMap { $0.first?.uppercased() }
            .joined()
    }

    @ViewBuilder
    private var projectIcon: some View {
        if let project = project, let iconPath = project.detectedIconPath,
           let nsImage = NSImage(contentsOfFile: iconPath) {
            Image(nsImage: nsImage)
                .resizable()
                .frame(width: 28, height: 28)
                .cornerRadius(6)
        } else {
            Text(initials)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(isActive ? Color.accentBlue : Color.bgHover)
                .foregroundColor(.white)
                .cornerRadius(6)
        }
    }

    var body: some View {
        let _ = project?.worktrees.count
        VStack(spacing: 2) {
            ZStack(alignment: .trailing) {
                Button(action: {
                    workspaceVM.setActiveProject(id: projectId)
                }) {
                    HStack(spacing: 8) {
                        projectIcon

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(project?.name ?? "")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }

                            if let worktree = activeWorktree {
                                HStack(spacing: 4) {
                                    Text(worktree.displayName)
                                        .font(.system(size: 10))
                                        .foregroundColor(.textSecondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: 160, alignment: .leading)

                                    Spacer()
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.leading, 8)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(BorderlessButtonStyle())
                .contextMenu {
                    Button("Change Icon") { showIconPicker = true }
                    if project?.hasCustomIcon == true {
                        Divider()
                        Button("Remove Icon") {
                            workspaceVM.updateProjectIcon(id: projectId, iconPath: nil)
                        }
                    }
                    Divider()
                    Button("Rename") {
                        renameName = project?.name ?? ""
                        renameDirectory = false
                        showRenameModal = true
                    }
                    Button("Remove") { workspaceVM.removeProject(id: projectId) }
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isWorktreesExpanded.toggle()
                        workspaceVM.setWorktreesExpanded(projectId: projectId, expanded: isWorktreesExpanded)
                    }
                }) {
                    Image(systemName: isWorktreesExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.textTertiary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 8)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isActive ? Color.bgTertiary : Color.clear)
            .cornerRadius(8)

            if isWorktreesExpanded {
                worktreesList
            }
        }
        .onAppear {
            isWorktreesExpanded = project?.isWorktreesExpanded ?? false
        }
        .onChange(of: project?.isWorktreesExpanded) { newValue in
            if let newValue {
                isWorktreesExpanded = newValue
            }
        }
        .sheet(isPresented: $showIconPicker) {
            if let project = project {
                IconPickerView(project: project, workspaceVM: workspaceVM)
            }
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
                            workspaceVM.renameProject(id: projectId, newName: renameName, renameDirectory: renameDirectory)
                        }
                        showRenameModal = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 300, height: 180)
        }
        .sheet(isPresented: $showAddWorktree) {
            AddWorktreeView(projectId: projectId)
                .environmentObject(workspaceVM)
        }
    }

    private var worktreesList: some View {
        let worktrees = sortedWorktrees
        return VStack(spacing: 1) {
            ForEach(worktrees) { worktree in
                let count = workspaceVM.getChangesCount(forWorktreeId: worktree.id)
                WorktreeRow(
                    projectId: projectId,
                    worktree: worktree,
                    isActive: worktree.id == activeWorktree?.id,
                    onSelect: {
                        workspaceVM.setActiveWorktree(projectId: projectId, worktreeId: worktree.id)
                    },
                    onRemove: !worktree.isMain ? {
                        contextMenuWorktree = worktree
                        showWorktreeContextMenu = true
                    } : nil,
                    changes: count
                )
            }

            if canAddWorktree {
                Button(action: { showAddWorktree = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                        Text("Add Worktree")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 24)
                    .background(Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 8)
        .confirmationDialog("Remove Worktree", isPresented: $showWorktreeContextMenu, presenting: contextMenuWorktree) { worktree in
            Button("Remove Worktree", role: .destructive) {
                workspaceVM.removeWorktree(projectId: projectId, worktreeId: worktree.id, deleteBranch: false)
            }
            Button("Remove Worktree and Branch", role: .destructive) {
                workspaceVM.removeWorktree(projectId: projectId, worktreeId: worktree.id, deleteBranch: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: { worktree in
            Text("Choose how to remove '\(worktree.displayName)' worktree")
        }
    }

    private var sortedWorktrees: [Worktree] {
        guard let proj = workspaceVM.projects.first(where: { $0.id == projectId }) else { return [] }
        return proj.worktrees.sorted { wt1, wt2 in
            if wt1.isMain { return true }
            if wt2.isMain { return false }
            return wt1.name < wt2.name
        }
    }

    private var canAddWorktree: Bool {
        guard let proj = workspaceVM.projects.first(where: { $0.id == projectId }) else { return false }
        return proj.worktrees.count < 5
    }
}

struct WorktreeRow: View {
    let projectId: String
    let worktree: Worktree
    let isActive: Bool
    let onSelect: () -> Void
    let onRemove: (() -> Void)?
    let changes: (added: Int, deleted: Int)

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onSelect) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundColor(isActive ? Color.textSecondary : Color.textTertiary)

                    Text(worktree.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(isActive ? .textPrimary : .textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: 100, alignment: .leading)

                    if changes.added > 0 || changes.deleted > 0 {
                        HStack(spacing: 2) {
                            Text("+\(changes.added)")
                                .foregroundColor(.green)
                            Text("-\(changes.deleted)")
                                .foregroundColor(.red)
                        }
                        .font(.system(size: 10, weight: .medium))
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentRed)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 4)
            }
        }
        .padding(.leading, 12)
        .padding(.vertical, 4)
        .background(isActive ? Color.textSecondary.opacity(0.2) : Color.clear)
        .cornerRadius(4)
    }
}

struct SidebarBottomBar: View {
    @Binding var expanded: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        Group {
            if expanded {
                HStack(spacing: 4) {
                    bottomButtons
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
            } else {
                VStack(spacing: 4) {
                    bottomButtons
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .foregroundColor(.textPrimary)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.borderDefault),
            alignment: .top
        )
    }

    private var bottomButtons: some View {
        Group {
            Button(action: onOpenSettings) {
                Image(systemName: "gear")
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 36, height: 36)
            .background(Color.clear)
            .cornerRadius(8)

            if expanded { Spacer() }

            Button(action: { expanded.toggle() }) {
                Image(systemName: expanded ? "sidebar.left" : "sidebar.right")
                    .font(.system(size: 14))
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 36, height: 36)
            .background(Color.clear)
            .cornerRadius(8)
        }
    }
}

struct ProjectRowCollapsed: View {
    let projectId: String
    @EnvironmentObject var workspaceVM: WorkspaceService
    @EnvironmentObject var terminalVM: TerminalViewModel

    private var project: Project? {
        workspaceVM.projects.first { $0.id == projectId }
    }

    var isActive: Bool {
        workspaceVM.activeProject?.id == projectId
    }

    private var initials: String {
        guard let project = project else { return "" }
        return project.name
            .split { $0.isWhitespace || $0 == "_" || $0 == "-" }
            .prefix(2)
            .compactMap { $0.first?.uppercased() }
            .joined()
    }

    @ViewBuilder
    private var projectIcon: some View {
        if let project = project, let iconPath = project.detectedIconPath,
           let nsImage = NSImage(contentsOfFile: iconPath) {
            Image(nsImage: nsImage)
                .resizable()
                .frame(width: 36, height: 36)
                .cornerRadius(8)
        } else {
            Text(initials)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(isActive ? Color.accentBlue : Color.bgTertiary)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }

    var body: some View {
        Button(action: {
            workspaceVM.setActiveProject(id: projectId)
        }) {
            projectIcon
        }
        .buttonStyle(BorderlessButtonStyle())
        .frame(width: 36, height: 36)
        .help(project?.name ?? "")
    }
}