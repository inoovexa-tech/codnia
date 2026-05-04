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
