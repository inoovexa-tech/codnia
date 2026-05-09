import SwiftUI

struct AddWorktreeView: View {
    let projectId: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workspaceVM: WorkspaceService
    @EnvironmentObject var gitVM: GitViewModel

    @State private var selectedBranch: String = ""
    @State private var newBranchName: String = ""
    @State private var createNewBranch: Bool = false
    @State private var isLoading: Bool = false
    @State private var isDropdownOpen: Bool = false
    @State private var errorMessage: String?
    @State private var availableBranches: [String] = []

    private var project: Project? {
        workspaceVM.projects.first { $0.id == projectId }
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Add Worktree")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(Color.bgHover)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Branch")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)

                if createNewBranch {
                    TextField("New branch name", text: $newBranchName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            isDropdownOpen.toggle()
                            if isDropdownOpen {
                                refreshBranches()
                            }
                        } label: {
                            HStack {
                                Text(selectedBranch.isEmpty ? "Select a branch" : selectedBranch)
                                    .foregroundColor(selectedBranch.isEmpty ? Color.textTertiary : Color.textPrimary)
                                Spacer()
                                Image(systemName: isDropdownOpen ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.textTertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.bgTertiary)
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())

                        if isDropdownOpen && !availableBranches.isEmpty {
                            VStack(alignment: .leading, spacing: 1) {
                                ForEach(availableBranches, id: \.self) { branch in
                                    Button {
                                        selectedBranch = branch
                                        isDropdownOpen = false
                                    } label: {
                                        Text(branch)
                                            .foregroundColor(Color.textPrimary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.bgSecondary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.borderLight, lineWidth: 1)
                            )
                        }
                    }
                    .frame(width: 280)
                }

                Toggle("Create new branch", isOn: $createNewBranch)
                    .font(.system(size: 12))
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    addWorktree()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canAdd || isLoading)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onAppear {
            refreshBranches()
        }
    }

    private func refreshBranches() {
        if let worktree = project?.activeWorktree {
            Task {
                await gitVM.refreshAll(for: worktree.path)
                await MainActor.run {
                    let existingBranches = Set(project?.worktrees.map { $0.branch } ?? [])
                    availableBranches = gitVM.branches.filter { !existingBranches.contains($0) }
                }
            }
        }
    }

    private var canAdd: Bool {
        if createNewBranch {
            return !newBranchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !selectedBranch.isEmpty
    }

    private func addWorktree() {
        guard let proj = project else {
            return
        }

        let branchName: String
        if createNewBranch {
            branchName = newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            branchName = selectedBranch
        }

        guard !branchName.isEmpty else {
            errorMessage = "Please select or enter a branch name"
            return
        }

        let projectPath = proj.path
        let parentPath = (projectPath as NSString).deletingLastPathComponent
        let projectName = (projectPath as NSString).lastPathComponent
        let worktreePath = (parentPath as NSString).appendingPathComponent("\(projectName)-\(branchName)")

        workspaceVM.addWorktree(
            projectId: projectId,
            branch: branchName,
            worktreePath: worktreePath,
            createBranch: createNewBranch,
            deleteBranchOnRemove: false
        )

        dismiss()
    }
}