import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsService
    @EnvironmentObject var pluginService: PluginService
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            Header
            Tabs
            Divider().background(Color.borderDefault)
            ContentArea
        }
        .frame(width: 700, height: 540)
        .background(Color.bgPrimary)
    }

    private var Header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.bgPrimary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
    }

    private var Tabs: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(selectedTab == tab ? .textPrimary : .textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(selectedTab == tab ? Color.bgSecondary : Color.clear)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.bgPrimary)
    }

    private var ContentArea: some View {
        ScrollView {
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsSection()
                case .editor:
                    EditorSettingsSection()
                case .terminal:
                    TerminalSettingsSection()
                case .browser:
                    BrowserSettingsSection()
                case .keyboard:
                    KeyboardSettingsSection()
                case .plugins:
                    PluginsSettingsSection()
                        .environmentObject(pluginService)
                }
            }
            .padding(20)
        }
        .background(Color.bgPrimary)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case editor = "Editor"
    case terminal = "Terminal"
    case browser = "Browser"
    case keyboard = "Keyboard"
    case plugins = "Plugins"

    var id: String { rawValue }
}

struct GeneralSettingsSection: View {
    @EnvironmentObject var settings: SettingsService
    @State private var showUploadAlert = false
    @State private var uploadMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader("Appearance")
            SettingsRow(label: "Theme", description: "Editor color theme") {
                HStack(spacing: 8) {
                    Button {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.json]
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        panel.allowsMultipleSelection = false
                        panel.message = "Select a Codnia theme JSON file"
                        panel.begin { response in
                            if response == .OK, let url = panel.url {
                                do {
                                    let data = try Data(contentsOf: url)
                                    let theme = try JSONDecoder().decode(CodTheme.self, from: data)
                                    ThemeManager.shared.saveCustomTheme(theme)
                                    settings.editorTheme = theme.name
                                    ThemeManager.shared.applyCustom(theme)
                                    settings.save()
                                } catch {
                                    uploadMessage = "Error: \(error.localizedDescription)"
                                    showUploadAlert = true
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Upload custom theme JSON")
                }
            }
            .alert("Upload Theme", isPresented: $showUploadAlert) {
                Button("OK") { showUploadAlert = false }
            } message: {
                Text(uploadMessage)
            }

            ThemeSelectorGrid(selected: $settings.editorTheme, onSelect: { name in
                settings.editorTheme = name
                ThemeManager.shared.apply(name)
                settings.save()
            })

            SettingsSectionHeader("Behavior")
            SettingsToggleRow(label: "Auto Save", description: "Automatically save files", isOn: $settings.autoSave)
                .onChange(of: settings.autoSave) { _ in settings.save() }

            SettingsRow(label: "Default Tab on Project Open", description: "Tab type to open when opening a project with no tabs") {
                Picker("", selection: $settings.defaultTabOnProjectOpen) {
                    Text("Terminal").tag("terminal")
                    Text("OpenCode Agent").tag("opencode")
                    Text("Claude Agent").tag("claude")
                    Text("Codex Agent").tag("codex")
                    Text("None").tag("none")
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 200)
                .onChange(of: settings.defaultTabOnProjectOpen) { _ in settings.save() }
            }
        }
    }
}

struct EditorSettingsSection: View {
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader("Font")
            SettingsRow(label: "Font Size", description: "Editor font size in points") {
                HStack {
                    Slider(value: $settings.fontSize, in: 8 ... 32, step: 1)
                        .onChange(of: settings.fontSize) { _ in settings.save() }
                    Text("\(Int(settings.fontSize))")
                        .foregroundColor(.textSecondary)
                        .frame(width: 30)
                }
                .frame(width: 280)
            }

            SettingsSectionHeader("Behavior")
            SettingsToggleRow(label: "Word Wrap", description: "Wrap lines at viewport width", isOn: $settings.wordWrap)
                .onChange(of: settings.wordWrap) { _ in settings.save() }
            SettingsToggleRow(label: "Line Numbers", description: "Show line numbers in gutter", isOn: $settings.showLineNumbers)
                .onChange(of: settings.showLineNumbers) { _ in settings.save() }

            SettingsRow(label: "Tab Size", description: "Number of spaces per tab") {
                Picker("", selection: $settings.tabSize) {
                    Text("2 spaces").tag(2)
                    Text("4 spaces").tag(4)
                    Text("8 spaces").tag(8)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            .onChange(of: settings.tabSize) { _ in
                settings.save()
            }
        }
    }
}

struct TerminalSettingsSection: View {
    @EnvironmentObject var settings: SettingsService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader("Font")
            SettingsRow(label: "Font Size", description: "Terminal font size in points") {
                HStack {
                    Slider(value: $settings.terminalFontSize, in: 8 ... 32, step: 1)
                        .onChange(of: settings.terminalFontSize) { _ in settings.save() }
                    Text("\(Int(settings.terminalFontSize))")
                        .foregroundColor(.textSecondary)
                        .frame(width: 30)
                }
                .frame(width: 280)
            }

            SettingsSectionHeader("Buffer")
            SettingsRow(label: "Scrollback", description: "Number of lines in scrollback buffer") {
                TextField("10000", value: $settings.terminalScrollback, formatter: NumberFormatter())
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 120)
                    .padding(4)
                    .background(Color.bgTertiary)
                    .cornerRadius(4)
                    .onChange(of: settings.terminalScrollback) { _ in settings.save() }
            }

        }
    }
}

struct BrowserSettingsSection: View {
    @EnvironmentObject var settings: SettingsService
    @State private var defaultLocation: BrowserOpenIn = .tab

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader("Browser Emulator")

            SettingsToggleRow(
                label: "Enable Browser Emulator",
                description: "Show browser tabs in the editor",
                isOn: $settings.browserEnabled
            )
            .onChange(of: settings.browserEnabled) { _ in settings.save() }

            SettingsRow(label: "Default URL", description: "URL to open when clicking the globe icon") {
                TextField("about:blank", text: $settings.browserDefaultURL)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 280)
                    .padding(6)
                    .background(Color.bgTertiary)
                    .cornerRadius(4)
                    .onChange(of: settings.browserDefaultURL) { _ in settings.save() }
            }

            SettingsRow(label: "Default Location", description: "Where to open the browser by default") {
                Picker("", selection: $settings.browserDefaultLocation) {
                    ForEach(BrowserOpenIn.allCases) { loc in
                        Text(loc.displayName).tag(loc.rawValue)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 160)
                .onChange(of: settings.browserDefaultLocation) { _ in settings.save() }
            }

            SettingsToggleRow(
                label: "Auto-Redirect",
                description: "Auto-open localhost/private IP URLs in browser tab (off = show prompt)",
                isOn: $settings.browserAutoRedirect
            )
            .onChange(of: settings.browserAutoRedirect) { _ in settings.save() }

            SettingsSectionHeader("URL Interception")

            SettingsToggleRow(
                label: "Intercept localhost",
                description: "Detect http://localhost and http://127.0.0.1 URLs in terminal",
                isOn: $settings.browserInterceptLocalhost
            )
            .onChange(of: settings.browserInterceptLocalhost) { _ in settings.save() }

            SettingsToggleRow(
                label: "Intercept private IPs",
                description: "Detect 10.x.x.x, 192.168.x.x, 172.16-31.x.x URLs in terminal",
                isOn: $settings.browserInterceptPrivateIPs
            )
            .onChange(of: settings.browserInterceptPrivateIPs) { _ in settings.save() }
        }
    }
}

struct KeyboardSettingsSection: View {
    @State private var editingAction: String? = nil
    @State private var editingValue: String = ""
    @ObservedObject private var shortcutsService = KeyboardShortcutsService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader("Shortcuts")

            ForEach(Array(shortcutsService.shortcuts.keys.sorted()), id: \.self) { action in
                let shortcut = shortcutsService.shortcuts[action] ?? ""
                HStack {
                    Text(action)
                        .font(.system(size: 13))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    if editingAction == action {
                        TextField("Shortcut", text: $editingValue)
                            .frame(width: 120)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(4)
                            .background(Color.bgTertiary)
                            .cornerRadius(4)
                            .onSubmit {
                                shortcutsService.update(action: action, shortcut: editingValue)
                                editingAction = nil
                            }
                    } else {
                        Button(action: {
                            editingAction = action
                            editingValue = shortcut
                        }) {
                            Text(shortcut)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.bgTertiary)
                                .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            Button("Reset to Defaults") {
                shortcutsService.reset()
            }
            .font(.system(size: 12))
            .foregroundColor(.accentRed)
        }
    }
}

struct SettingsSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.textSecondary)
            .padding(.top, 8)
    }
}

struct SettingsRow<Content: View>: View {
    let label: String
    let description: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.textPrimary)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
            }
            Spacer()
            content
        }
    }
}

struct PluginsSettingsSection: View {
    @EnvironmentObject var pluginService: PluginService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader("Installed Plugins")

            if pluginService.plugins.isEmpty {
                Text("No plugins installed")
                    .font(.system(size: 13))
                    .foregroundColor(.textTertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(pluginService.plugins) { plugin in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plugin.name)
                                .font(.system(size: 13))
                                .foregroundColor(.textPrimary)
                            Text("v\(plugin.version) by \(plugin.author)")
                                .font(.system(size: 10))
                                .foregroundColor(.textTertiary)
                            Text(plugin.description)
                                .font(.system(size: 11))
                                .foregroundColor(.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { pluginService.isActive(pluginId: plugin.id) },
                            set: { _ in pluginService.togglePlugin(pluginId: plugin.id) }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: Color.accentBlue))
                        .labelsHidden()
                    }
                    .padding(8)
                    .background(Color.bgTertiary)
                    .cornerRadius(6)

                    if plugin.id != pluginService.plugins.last?.id {
                        Divider()
                            .background(Color.borderDefault)
                    }
                }
            }

            SettingsSectionHeader("Marketplace")
            Text("Coming soon")
                .font(.system(size: 12))
                .foregroundColor(.textTertiary)
        }
    }
}

struct SettingsToggleRow: View {
    let label: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.textPrimary)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Color.accentBlue))
                .labelsHidden()
        }
    }
}

struct ThemeSelectorGrid: View {
    @Binding var selected: String
    let onSelect: (String) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(ThemeManager.shared.allThemes) { theme in
                themeCard(theme)
                    .onTapGesture { onSelect(theme.name) }
            }
        }
        .padding(.vertical, 4)
        .background(Color.bgTertiary.opacity(0.3))
        .cornerRadius(8)
    }

    func themeCard(_ theme: CodTheme) -> some View {
        let isSelected = selected == theme.name
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                paletteSwatch(theme.palette.bg)
                paletteSwatch(theme.palette.surface)
                paletteSwatch(theme.palette.accent)
                paletteSwatch(theme.palette.fg)
                paletteSwatch(theme.palette.syntax)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Text(theme.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSecondary)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentBlue : Color.clear, lineWidth: 2)
        )
    }

    func paletteSwatch(_ hex: String) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(hex: hex))
            .frame(width: 18, height: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.borderLight, lineWidth: 0.5)
            )
    }
}
