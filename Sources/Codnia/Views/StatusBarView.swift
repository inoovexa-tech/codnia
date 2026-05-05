import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var workspaceVM: WorkspaceService

    var body: some View {
        HStack(spacing: 16) {
            Text(branchText)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)

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

    private var branchText: String {
        if let project = workspaceVM.activeProject {
            return workspaceVM.branches[project.id] ?? "main"
        }
        return "main"
    }
}
