import SwiftUI

struct RoutineEditorView: View {
    let configID: String
    let schema: String
    let name: String
    let type: RoutineType

    @EnvironmentObject var databaseService: DatabaseConnectionService
    @Environment(\.dismiss) private var dismiss

    @State private var sourceCode = ""
    @State private var originalSource = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var hasChanges: Bool {
        sourceCode != originalSource && !sourceCode.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if isLoading {
                loadingState
            } else if let error = errorMessage, sourceCode.isEmpty {
                errorState(error)
            } else {
                editorContent
            }
            Divider()
            footer
        }
        .frame(width: 600, height: 500)
        .task { await loadSource() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: typeIcon)
                .font(.system(size: 12))
                .foregroundColor(typeColor)
            Text("Edit \(type.rawValue.capitalized)")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Text("\(schema).\(name)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.textTertiary)
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var typeIcon: String {
        switch type {
        case .view: return "eye"
        case .function: return "f.cursive"
        case .procedure: return "gearshape.2"
        }
    }

    private var typeColor: Color {
        switch type {
        case .view: return .accentBlue
        case .function: return .accentPurple
        case .procedure: return .accentOrange
        }
    }

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
            Text("Loading source code...")
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)
            Spacer()
        }
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(.accentRed)
            Text("Failed to load source")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
            Text(error)
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Source (\(type.rawValue.lowercased()))")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                if hasChanges {
                    Text("Unsaved changes")
                        .font(.system(size: 9))
                        .foregroundColor(.accentYellow)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                TextEditor(text: $sourceCode)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .frame(minWidth: 200, minHeight: 200)
                    .scrollContentBackground(.hidden)
                    .background(Color.bgSecondary)
            }
            .padding(8)
            .background(Color.bgSecondary)
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private var footer: some View {
        HStack {
            if let error = errorMessage, !sourceCode.isEmpty {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.accentRed)
                    .lineLimit(2)
            }
            Spacer()
            Button("Cancel", action: { dismiss() })
                .keyboardShortcut(.escape, modifiers: [])
            Button(action: saveSource) {
                HStack(spacing: 4) {
                    if isSaving { ProgressView().scaleEffect(0.5) }
                    Text("Apply")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(canSave ? Color.accentBlue : Color.gray)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canSave || isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var canSave: Bool {
        hasChanges && !isSaving
    }

    private func loadSource() async {
        isLoading = true
        errorMessage = nil
        let source = await databaseService.fetchRoutineSource(configID: configID, schema: schema, name: name, type: type)
        await MainActor.run {
            if source.isEmpty {
                errorMessage = "Could not load source code for this \(type.rawValue.lowercased())"
            } else {
                sourceCode = source
                originalSource = source
            }
            isLoading = false
        }
    }

    private func saveSource() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await databaseService.updateRoutine(configID: configID, schema: schema, name: name, type: type, source: sourceCode)
                await MainActor.run {
                    originalSource = sourceCode
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}
