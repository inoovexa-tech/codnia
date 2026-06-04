import SwiftUI

struct BrowserCredentialsView: View {
    @EnvironmentObject var appState: AppState
    @State private var revealPasswordFor: UUID?
    @State private var confirmClearAll: Bool = false
    @State private var pendingSave: BrowserSavedCredential?
    @State private var pendingPassword: String = ""

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            content
        }
        .onReceive(appState.credentialService.$pendingSave) { newValue in
            if let newValue, newValue != pendingSave {
                pendingSave = newValue
            }
        }
        .sheet(item: $pendingSave) { cred in
            savePromptSheet(for: cred)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            TextField("Search logins", text: $appState.credentialService.searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.bgTertiary)
                .cornerRadius(3)
            Text("\(appState.credentialService.credentials.count)")
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
            Button(action: { confirmClearAll = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.accentRed)
            .help("Delete all logins")
            .disabled(appState.credentialService.credentials.isEmpty)
            .alert("Delete all saved logins?", isPresented: $confirmClearAll) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    appState.credentialService.removeAll()
                }
            } message: {
                Text("This removes all saved logins from the Keychain for this worktree.")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private var content: some View {
        if appState.credentialService.credentials.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(appState.credentialService.groupedByHost, id: \.host) { group in
                        sectionHeader(group.host)
                        ForEach(group.items) { cred in
                            CredentialRow(
                                credential: cred,
                                isRevealed: revealPasswordFor == cred.id,
                                revealedPassword: revealPasswordFor == cred.id ? appState.credentialService.retrieve(cred) : nil,
                                onReveal: { revealPasswordFor = revealPasswordFor == cred.id ? nil : cred.id },
                                onRemove: { appState.credentialService.remove(cred) }
                            )
                        }
                    }
                }
            }
            .background(Color.bgPrimary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "key")
                .font(.system(size: 20))
                .foregroundColor(.textTertiary)
            Text("No saved logins")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
            Text("Enable auto-save in Settings to remember logins")
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionHeader(_ host: String) -> some View {
        HStack {
            Text(host)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.bgTertiary.opacity(0.3))
    }

    @ViewBuilder
    private func savePromptSheet(for credential: BrowserSavedCredential) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save login?")
                .font(.system(size: 14, weight: .semibold))
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .foregroundColor(.accentBlue)
                VStack(alignment: .leading) {
                    Text(credential.displayHost)
                        .font(.system(size: 11, weight: .medium))
                    Text(credential.username)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(8)
            .background(Color.bgTertiary)
            .cornerRadius(6)

            SecureField("Password (to store in Keychain)", text: $pendingPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 280)

            HStack {
                Spacer()
                Button("Not Now") {
                    appState.credentialService.cancelSave()
                    pendingPassword = ""
                    pendingSave = nil
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    appState.credentialService.confirmSave(credential, password: pendingPassword)
                    pendingPassword = ""
                    pendingSave = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(pendingPassword.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
    }
}

struct CredentialRow: View {
    let credential: BrowserSavedCredential
    let isRevealed: Bool
    let revealedPassword: String?
    let onReveal: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.circle")
                .font(.system(size: 10))
                .foregroundColor(.accentBlue)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(credential.username)
                    .font(.system(size: 10))
                    .foregroundColor(.textPrimary)
                if isRevealed, let password = revealedPassword {
                    Text(password)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.textSecondary)
                } else {
                    Text("••••••••")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.textTertiary)
                }
            }
            Spacer()
            Button(action: onReveal) {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .font(.system(size: 9))
                    .foregroundColor(.textTertiary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(PlainButtonStyle())
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 9))
                    .foregroundColor(.accentRed)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}
