import SwiftUI

struct SourceControlView: View {
    @EnvironmentObject var gitVM: GitViewModel
    @EnvironmentObject var workspaceVM: WorkspaceService

    @State private var newBranchName: String = ""
    @State private var showBranchDialog: Bool = false
    @State private var mergeBranchName: String = ""
    @State private var showMergeDialog: Bool = false
    @State private var deleteWorktreeAfterMerge = false
    @State private var hoveredFileId: String? = nil
    @State private var selectedForDiscard: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            if workspaceVM.activeProject == nil {
                emptyState
            } else {
                VStack(spacing: 0) {
                    branchHeader
                    actionButtons
                    ScrollView {
                        VStack(spacing: 0) {
                            stagedSection
                            unstagedSection
                        }
                    }
                    .frame(maxHeight: 300)
                    commitSection

                    Spacer()

                    if !gitVM.commitHistory.isEmpty {
                        ScrollView {
                            commitHistorySection
                        }
                        .frame(maxHeight: 200)
                    }

                    messagesView
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .onAppear {
            if workspaceVM.activeProject != nil {
                gitVM.refreshAll()
            }
        }
    }

    private var messagesView: some View {
        VStack(spacing: 0) {
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

    // MARK: - Commit History Section

    private var commitHistorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .foregroundColor(.borderDefault)
                .padding(.top, 8)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    gitVM.showCommitHistory.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: gitVM.showCommitHistory ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                    Text("History")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.textTertiary)
                    Spacer()
                    Text("\(gitVM.commitHistory.count)")
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(bgHex: "#2a2a2a"))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(PlainButtonStyle())

            if gitVM.showCommitHistory {
                ForEach(gitVM.commitHistory) { commit in
                    commitRow(commit: commit)
                }
            }
        }
    }

    private func commitRow(commit: GitService.CommitInfo) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 2) {
                Circle()
                    .fill(Color.accentBlue)
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(Color.borderDefault)
                    .frame(width: 1, height: 24)
            }
            .padding(.leading, 14)
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(commit.message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text(commit.shortHash)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.accentBlue)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentBlue.opacity(0.15))
                        .cornerRadius(3)

                    Text(commit.author)
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)

                    Text("·")
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)

                    Text(commit.date)
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                }
            }
            .padding(.vertical, 6)
            .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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

            if gitVM.isLoading || (gitVM.isRefreshing && !gitVM.isAutoRefreshing) {
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
                    gitVM.merge(branch: name, deleteWorktreeAfterMerge: deleteWorktreeAfterMerge)
                    mergeBranchName = ""
                    showMergeDialog = false
                    deleteWorktreeAfterMerge = false
                } label: {
                    Text("Merge")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentBlue)
            }

            Toggle("Delete worktree after merge", isOn: $deleteWorktreeAfterMerge)
                .font(.system(size: 10))
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(12)
        .frame(width: 260)
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

            if !gitVM.unstagedEntries.isEmpty {
                discardBar
            }
        }
    }

    private var discardBar: some View {
        HStack(spacing: 8) {
            Button {
                if selectedForDiscard.isEmpty {
                    discardAll()
                } else {
                    discardSelected()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                    Text(selectedForDiscard.isEmpty ? "Discard All" : "Discard Selected (\(selectedForDiscard.count))")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selectedForDiscard.isEmpty ? Color.red.opacity(0.2) : Color.accentBlue.opacity(0.2))
                .foregroundColor(selectedForDiscard.isEmpty ? .red : .accentBlue)
                .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())

            if !selectedForDiscard.isEmpty {
                Button {
                    selectedForDiscard.removeAll()
                } label: {
                    Text("Clear Selection")
                        .font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func discardAll() {
        for entry in gitVM.unstagedEntries {
            gitVM.discardFile(entry.filePath)
        }
    }

    private func discardSelected() {
        for filePath in selectedForDiscard {
            gitVM.discardFile(filePath)
        }
        selectedForDiscard.removeAll()
    }

    // MARK: - File Row

    private func fileRow(entry: GitStatusEntry, isStaged: Bool) -> some View {
        HStack(spacing: 6) {
            if !selectedForDiscard.isEmpty && !isStaged {
                Button {
                    if selectedForDiscard.contains(entry.filePath) {
                        selectedForDiscard.remove(entry.filePath)
                    } else {
                        selectedForDiscard.insert(entry.filePath)
                    }
                } label: {
                    Image(systemName: selectedForDiscard.contains(entry.filePath) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                        .foregroundColor(selectedForDiscard.contains(entry.filePath) ? .accentBlue : .textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }

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

            if let counts = gitVM.fileChangesCounts[entry.filePath], counts.added > 0 || counts.deleted > 0 {
                HStack(spacing: 2) {
                    Text("+\(counts.added)")
                        .foregroundColor(.green)
                    Text("-\(counts.deleted)")
                        .foregroundColor(.red)
                }
                .font(.system(size: 10, weight: .medium))
            }

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
                .opacity(hoveredFileId == entry.id && selectedForDiscard.isEmpty ? 0.8 : 0)
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
            .disabled(gitVM.isCommitting || gitVM.stagedEntries.isEmpty || gitVM.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var commitButtonColor: Color {
        if gitVM.isCommitting {
            return Color.accentBlue.opacity(0.5)
        }
        if gitVM.stagedEntries.isEmpty || gitVM.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
