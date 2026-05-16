import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var workspaceVM: WorkspaceService

    var body: some View {
        HStack(spacing: 16) {
            if workspaceVM.activeProject != nil {
                HStack(spacing: 4) {
                    Text(branchText)
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)

                    changesBadgeView
                        .font(.system(size: 11))
                }
            }

            Text("0 problems")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)

            Spacer()

            HStack(spacing: 2) {
                Button(action: {
                    editorVM.createTerminalTab(type: .opencode)
                }) {
                    Image(systemName: "command")
                        .font(.system(size: 11))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentBlue)

                Button(action: {
                    editorVM.createTerminalTab(type: .claude)
                }) {
                    Image(systemName: "circle")
                        .font(.system(size: 11))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentOrange)

                Button(action: {
                    editorVM.createTerminalTab(type: .codex)
                }) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 11))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentPurple)
            }

            Text("Spaces: 4")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)

            Text("UTF-8")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)

            Text(editorVM.currentLanguage)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)

            Text(editorVM.cursorPosition)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var changesBadgeView: some View {
        if let project = workspaceVM.activeProject {
            let changes = workspaceVM.getChangesCount(forProjectId: project.id)
            if changes.added > 0 || changes.deleted > 0 {
                HStack(spacing: 2) {
                    Text("+\(formatCount(changes.added))")
                        .foregroundColor(.green)
                    Text("-\(formatCount(changes.deleted))")
                        .foregroundColor(.red)
                }
            }
        }
    }

    private var branchText: String {
        if let project = workspaceVM.activeProject {
            return workspaceVM.getBranch(forProjectId: project.id)
        }
        return "main"
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return "\(count / 1000)k"
        }
        return "\(count)"
    }
}
