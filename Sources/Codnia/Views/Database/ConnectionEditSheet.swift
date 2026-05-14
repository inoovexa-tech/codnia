import SwiftUI

struct ConnectionEditSheet: View {
    @EnvironmentObject var databaseService: DatabaseConnectionService
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var type: DatabaseType = .postgres
    @State private var host: String = "localhost"
    @State private var port: String = "5432"
    @State private var user: String = "postgres"
    @State private var password: String = ""
    @State private var database: String = ""
    @State private var useSSL: Bool = false

    @State private var testState: TestState = .idle
    @State private var editingConfig: ConnectionConfig?

    private enum TestState: Equatable {
        case idle, testing, success, failed(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(editingConfig != nil ? "Edit Connection" : "New Connection")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.bgSecondary)
            .overlay(
                Rectangle().frame(height: 1).foregroundColor(.borderDefault),
                alignment: .bottom
            )

            ScrollView {
                VStack(spacing: 16) {
                    formField("Name", value: $name)
                    formField("Host", value: $host)
                    formField("Port", value: $port)
                    formField("User", value: $user)
                    secureField("Password", value: $password)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Database")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                        TextField("postgres", text: $database)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.bgTertiary)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.borderLight, lineWidth: 0.5)
                            )
                    }

                    Toggle(isOn: $useSSL) {
                        Text("Use SSL")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
                .padding(20)
            }

            Divider()

            HStack(spacing: 8) {
                if case .success = testState {
                    Text("Connection successful")
                        .font(.system(size: 12))
                        .foregroundColor(.accentGreen)
                } else if case .failed(let err) = testState {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(.accentRed)
                        .lineLimit(2)
                }

                Spacer()

                Button("Test Connection") {
                    testConnection()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(testingDisabled)

                Button("Save") {
                    saveConnection()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(saveDisabled)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 420, height: 520)
        .background(Color.bgPrimary)
        .onAppear(perform: loadExistingConfig)
    }

    private var testingDisabled: Bool {
        host.isEmpty || user.isEmpty || testState == .testing
    }

    private var saveDisabled: Bool {
        name.isEmpty || host.isEmpty || user.isEmpty
    }

    private func formField(_ label: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
            TextField("", text: value)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.bgTertiary)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.borderLight, lineWidth: 0.5)
                )
        }
    }

    private func secureField(_ label: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
            SecureField("", text: value)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.bgTertiary)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.borderLight, lineWidth: 0.5)
                )
        }
    }

    private func loadExistingConfig() {
        guard let config = editingConfig else { return }
        name = config.name
        type = config.type
        host = config.host
        port = String(config.port)
        user = config.user
        database = config.database ?? ""
        useSSL = config.useSSL
        if let saved = databaseService.password(for: config.id) {
            password = saved
        }
    }

    private func resolvedPassword(for configID: String) -> String {
        if !password.isEmpty { return password }
        return databaseService.password(for: configID) ?? ""
    }

    private func testConnection() {
        testState = .testing
        let config = buildConfig()

        Task {
            let pw = resolvedPassword(for: config.id)
            await databaseService.connect(config, password: pw)
            let state = databaseService.state(for: config.id)

            for _ in 0..<20 {
                let s = databaseService.state(for: config.id)
                if case .connected = s { break }
                if case .error = s { break }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }

            let finalState = databaseService.state(for: config.id)
            switch finalState {
            case .connected:
                testState = .success
                await databaseService.disconnect(configID: config.id)
            case .error(let msg):
                testState = .failed(msg)
            default:
                testState = .failed("Connection timed out")
            }
        }
    }

    private func saveConnection() {
        let config = buildConfig()
        let pw = resolvedPassword(for: config.id)

        if !pw.isEmpty {
            KeychainHelper.save(account: config.id, password: pw)
        }
        databaseService.addConnection(config)

        if !databaseService.state(for: config.id).isConnected && !pw.isEmpty {
            Task { await databaseService.connect(config, password: pw) }
        }

        dismiss()
    }

    private func buildConfig() -> ConnectionConfig {
        ConnectionConfig(
            id: editingConfig?.id ?? UUID().uuidString,
            name: name,
            type: type,
            host: host,
            port: Int(port) ?? 5432,
            user: user,
            database: database.isEmpty ? nil : database,
            useSSL: useSSL
        )
    }
}
