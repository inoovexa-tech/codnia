import SwiftUI

struct SourceControlView: View {
    @EnvironmentObject var gitVM: GitViewModel
    @EnvironmentObject var workspaceVM: WorkspaceService

    @State private var newBranchName: String = ""
    @State private var showBranchDialog: Bool = false
    @State private var mergeBranchName: String = ""
    @State private var showMergeDialog: Bool = false
    @State private var hoveredFileId: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            if workspaceVM.activeProject == nil {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        branchHeader
                        actionButtons
                        stagedSection
                        unstagedSection
                        commitSection
                    }
                }

                if let message = gitVM.actionMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                        Spacer()
                        Button { gitVM.clearMessages() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                }

                if let error = gitVM.actionError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 12))
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                        Spacer()
                        Button { gitVM.clearMessages() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                }
            }
        }
        .onAppear {
            if workspaceVM.activeProject != nil {
                gitVM.refreshAll()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 24))
                .foregroundColor(.textTertiary)
            Text("No project open")
                .font(.system(size: 12))
                .foregroundColor(.textTertiary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Branch Header

    private var branchHeader: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12))
                .foregroundColor(.accentBlue)

            Button {
                showBranchDialog = true
            } label: {
                HStack(spacing: 4) {
                    Text(gitVM.currentBranch.isEmpty ? "main" : gitVM.currentBranch)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(.textTertiary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: $showBranchDialog) {
                branchPopover
            }

            Spacer()

            if gitVM.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            } else {
                Button { gitVM.refreshAll() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.textTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var branchPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Branches")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 8)
                .padding(.top, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(gitVM.branches, id: \.self) { branch in
                        Button {
                            gitVM.checkoutBranch(name: branch)
                            showBranchDialog = false
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: branch == gitVM.currentBranch
                                    ? "checkmark.circle.fill"
                                    : "circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(branch == gitVM.currentBranch
                                        ? .accentBlue : .textTertiary)

                                Text(branch)
                                    .font(.system(size: 12))
                                    .foregroundColor(.textPrimary)

                                if branch == gitVM.currentBranch {
                                    Text("current")
                                        .font(.system(size: 9))
                                        .foregroundColor(.textTertiary)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color(bgHex: "#2a2a2a"))
                                        .cornerRadius(3)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(maxHeight: 200)

            Divider()

            HStack(spacing: 6) {
                TextField("New branch name", text: $newBranchName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(bgHex: "#1c1c1c"))
                    .cornerRadius(4)

                Button {
                    let name = newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    gitVM.createBranch(name: name)
                    newBranchName = ""
                    showBranchDialog = false
                } label: {
                    Text("Create")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentBlue)
            }
            .padding(8)
        }
        .frame(width: 240)
        .background(Color.bgSecondary)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 4) {
            Button { gitVM.pull() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 11))
                    Text("Pull")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(bgHex: "#1c1c1c"))
                .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textPrimary)

            Button { gitVM.push() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.to.line")
                        .font(.system(size: 11))
                    Text("Push")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(bgHex: "#1c1c1c"))
                .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textPrimary)

            Button { gitVM.fetch() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.arrow.up")
                        .font(.system(size: 11))
                    Text("Fetch")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(bgHex: "#1c1c1c"))
                .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textPrimary)

            Spacer()

            Button {
                showMergeDialog = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.merge")
                        .font(.system(size: 11))
                    Text("Merge")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(bgHex: "#1c1c1c"))
                .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textPrimary)
            .popover(isPresented: $showMergeDialog) {
                mergePopover
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var mergePopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Merge branch into \(gitVM.currentBranch)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textPrimary)

            HStack(spacing: 6) {
                TextField("Branch name", text: $mergeBranchName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(bgHex: "#1c1c1c"))
                    .cornerRadius(4)

                Button {
                    let name = mergeBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    gitVM.merge(branch: name)
                    mergeBranchName = ""
                    showMergeDialog = false
                } label: {
                    Text("Merge")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentBlue)
            }
        }
        .padding(12)
        .frame(width: 240)
        .background(Color.bgSecondary)
    }

    // MARK: - Staged Section

    private var stagedSection: some View {
        VStack(spacing: 0) {
            if !gitVM.stagedEntries.isEmpty {
                sectionHeader(
                    title: "Staged",
                    count: gitVM.stagedEntries.count,
                    actionTitle: "Unstage All",
                    action: {
                        for entry in gitVM.stagedEntries {
                            gitVM.unstageFile(entry.filePath)
                        }
                    }
                )

                ForEach(gitVM.stagedEntries) { entry in
                    fileRow(entry: entry, isStaged: true)
                }

                Divider()
                    .foregroundColor(.borderDefault)
                    .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Unstaged Section

    private var unstagedSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: "Changes",
                count: gitVM.unstagedEntries.count,
                actionTitle: gitVM.unstagedEntries.isEmpty ? nil : "Stage All",
                action: { gitVM.stageAll() }
            )

            if gitVM.unstagedEntries.isEmpty && gitVM.stagedEntries.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.green.opacity(0.6))
                    Text("No changes")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }

            ForEach(gitVM.unstagedEntries) { entry in
                fileRow(entry: entry, isStaged: false)
            }
        }
    }

    // MARK: - File Row

    private func fileRow(entry: GitStatusEntry, isStaged: Bool) -> some View {
        HStack(spacing: 6) {
            statusIcon(for: entry.status, isStaged: isStaged)

            Button {
                gitVM.openDiff(for: entry)
            } label: {
                Text(entry.filePath)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
            .help("View diff")

            if isStaged {
                Button { gitVM.unstageFile(entry.filePath) } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 11))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.textTertiary)
                .opacity(hoveredFileId == entry.id ? 0.8 : 0)
                .help("Unstage")
            } else {
                Button { gitVM.discardFile(entry.filePath) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.red.opacity(0.7))
                .opacity(hoveredFileId == entry.id ? 0.8 : 0)
                .help("Discard changes")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(hoveredFileId == entry.id ? Color(bgHex: "#1c1c1c") : Color.clear)
        .cornerRadius(3)
        .onHover { hovering in
            hoveredFileId = hovering ? entry.id : nil
        }
    }

    private func statusIcon(for status: String, isStaged: Bool) -> some View {
        let iconName: String
        let color: Color

        switch status {
        case "M":
            iconName = isStaged ? "circle.fill" : "circle"
            color = .accentBlue
        case "A":
            iconName = isStaged ? "circle.fill" : "circle"
            color = .green
        case "D":
            iconName = "minus.circle"
            color = .red
        case "?":
            iconName = "questionmark.circle"
            color = .textTertiary
        case "R":
            iconName = "arrow.forward.circle"
            color = .accentBlue
        default:
            iconName = isStaged ? "circle.fill" : "circle"
            color = .textTertiary
        }

        return Image(systemName: iconName)
            .font(.system(size: 10))
            .foregroundColor(color)
            .frame(width: 16)
    }

    // MARK: - Commit Section

    private var commitSection: some View {
        VStack(spacing: 6) {
            Divider()
                .foregroundColor(.borderDefault)

            TextField("Commit message (Cmd+Enter to commit)",
                      text: $gitVM.commitMessage)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(bgHex: "#1c1c1c"))
                .cornerRadius(4)
                .onSubmit { gitVM.commit() }

            Button {
                gitVM.commit()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 12))
                    Text("Commit")
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(commitButtonColor)
                .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.white)
            .disabled(gitVM.isCommitting || gitVM.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var commitButtonColor: Color {
        if gitVM.isCommitting {
            return Color.accentBlue.opacity(0.5)
        }
        if gitVM.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Color.accentBlue.opacity(0.3)
        }
        return Color.accentBlue
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, count: Int, actionTitle: String?, action: (() -> Void)?) -> some View {
        HStack(spacing: 4) {
            Text("\(title) (\(count))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textTertiary)

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentBlue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

private extension Color {
    init(bgHex: String) {
        self = Color(hex: bgHex)
    }
}
