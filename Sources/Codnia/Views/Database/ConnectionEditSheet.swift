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
    @State private var filePath: String = ""

    @State private var useSSH: Bool = false
    @State private var sshHost: String = ""
    @State private var sshPort: String = "22"
    @State private var sshUser: String = ""
    @State private var sshAuthMethod: SSHConfig.SSHAuthMethod = .key
    @State private var sshKeyPath: String = ""

    @State private var group: String = ""
    @State private var environment: String = ""

    @State private var testState: TestState = .idle
    @State private var editingConfig: ConnectionConfig?

    private let environmentOptions = ["", "dev", "staging", "prod"]

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

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                        Picker("", selection: $type) {
                            ForEach(DatabaseType.allCases, id: \.self) { t in
                                Text(t.rawValue.capitalized).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: type) { newType in
                            updateDefaults(for: newType)
                        }
                    }

                    if type == .sqlite {
                        sqliteFields
                    } else {
                        serverFields
                    }

                    sshSection

                    groupSection
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
        .frame(width: 440, height: 620)
        .background(Color.bgPrimary)
        .onAppear(perform: loadExistingConfig)
    }

    @ViewBuilder
    private var sqliteFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Database File")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
            HStack(spacing: 8) {
                TextField("Select a .db file...", text: $filePath)
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
                Button("Browse") {
                    browseForSQLiteFile()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        databaseField
    }

    @ViewBuilder
    private var serverFields: some View {
        formField("Host", value: $host)
        formField("Port", value: $port)
        formField("User", value: $user)
        secureField("Password", value: $password)
        databaseField

        Toggle(isOn: $useSSL) {
            Text("Use SSL")
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    @ViewBuilder
    private var databaseField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Database")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
            TextField(type == .postgres ? "postgres" : (type == .mysql ? "mysql" : ""), text: $database)
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

    @ViewBuilder
    private var sshSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $useSSH) {
                Text("Use SSH Tunnel")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            if useSSH {
                VStack(spacing: 10) {
                    formField("SSH Host", value: $sshHost)
                    formField("SSH Port", value: $sshPort)
                    formField("SSH User", value: $sshUser)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Auth Method")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                        Picker("", selection: $sshAuthMethod) {
                            Text("SSH Key").tag(SSHConfig.SSHAuthMethod.key)
                            Text("Password").tag(SSHConfig.SSHAuthMethod.password)
                        }
                        .pickerStyle(.segmented)
                    }

                    if sshAuthMethod == .key {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Key Path (optional)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.textSecondary)
                            TextField("~/.ssh/id_rsa", text: $sshKeyPath)
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
                }
                .padding(.leading, 8)
            }
        }
        .padding(12)
        .background(Color.bgSecondary.opacity(0.5))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.borderLight, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var groupSection: some View {
        VStack(spacing: 10) {
            formField("Group", value: $group)

            VStack(alignment: .leading, spacing: 6) {
                Text("Environment")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
                Picker("", selection: $environment) {
                    ForEach(environmentOptions, id: \.self) { env in
                        Text(env.isEmpty ? "None" : env.capitalized).tag(env)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func updateDefaults(for newType: DatabaseType) {
        switch newType {
        case .postgres:
            host = "localhost"
            port = "5432"
            user = "postgres"
            useSSL = false
        case .mysql:
            host = "localhost"
            port = "3306"
            user = "root"
            useSSL = false
        case .sqlite:
            filePath = ""
        }
    }

    private func browseForSQLiteFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "db") ?? .data, .init(filenameExtension: "sqlite") ?? .data, .init(filenameExtension: "sqlite3") ?? .data]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                filePath = url.path
            }
        }
    }

    private var testingDisabled: Bool {
        if type == .sqlite { return testState == .testing }
        return host.isEmpty || user.isEmpty || testState == .testing
    }

    private var saveDisabled: Bool {
        if type == .sqlite { return name.isEmpty || filePath.isEmpty }
        return name.isEmpty || host.isEmpty || user.isEmpty
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
        filePath = config.filePath ?? ""
        group = config.group ?? ""
        environment = config.environment ?? ""
        if let saved = databaseService.password(for: config.id) {
            password = saved
        }
        if let ssh = config.sshConfig {
            useSSH = true
            sshHost = ssh.host
            sshPort = String(ssh.port)
            sshUser = ssh.user
            sshAuthMethod = ssh.authMethod
            sshKeyPath = ssh.keyPath ?? ""
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

            for _ in 0..<30 {
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
        let defaultPort: Int = type == .mysql ? 3306 : 5432

        let ssh: SSHConfig? = useSSH && !sshHost.isEmpty ? SSHConfig(
            host: sshHost,
            port: Int(sshPort) ?? 22,
            user: sshUser,
            authMethod: sshAuthMethod,
            keyPath: sshKeyPath.isEmpty ? nil : sshKeyPath
        ) : nil

        return ConnectionConfig(
            id: editingConfig?.id ?? UUID().uuidString,
            name: name,
            type: type,
            host: host,
            port: Int(port) ?? defaultPort,
            user: user,
            database: database.isEmpty ? nil : database,
            useSSL: type == .sqlite ? false : useSSL,
            filePath: type == .sqlite ? (filePath.isEmpty ? nil : filePath) : nil,
            sshConfig: ssh,
            group: group.isEmpty ? nil : group,
            environment: environment.isEmpty ? nil : environment
        )
    }
}
