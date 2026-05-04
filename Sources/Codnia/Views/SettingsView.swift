import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsService
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.bgPrimary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.borderDefault),
                alignment: .bottom
            )

            // Tabs
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(selectedTab == tab ? .textPrimary : .textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(selectedTab == tab ? Color.bgTertiary : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.bgPrimary)

            Divider()
                .background(Color.borderDefault)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsSection()
                    case .editor:
                        EditorSettingsSection()
                    case .terminal:
                        TerminalSettingsSection()
                    case .keyboard:
                        KeyboardSettingsSection()
                    }
                }
                .padding(20)
            }
            .background(Color.bgPrimary)
        }
        .frame(minWidth: 700, minHeight: 540)
        .background(Color.bgPrimary)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case editor = "Editor"
    case terminal = "Terminal"
    case keyboard = "Keyboard"

    var id: String { rawValue }
}

struct GeneralSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader("Appearance")
            SettingsRow(label: "Theme", description: "Editor color theme") {
                Picker("", selection: .constant("dark-pure")) {
                    Text("Dark Pure").tag("dark-pure")
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 200)
            }

            SettingsSectionHeader("Behavior")
            SettingsToggleRow(label: "Auto Save", description: "Automatically save files", isOn: .constant(false))
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
                    Text("\(Int(settings.fontSize))")
                        .foregroundColor(.textSecondary)
                        .frame(width: 30)
                }
                .frame(width: 280)
            }

            SettingsSectionHeader("Behavior")
            SettingsToggleRow(label: "Word Wrap", description: "Wrap lines at viewport width", isOn: $settings.wordWrap)
            SettingsToggleRow(label: "Line Numbers", description: "Show line numbers in gutter", isOn: $settings.showLineNumbers)

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
            }
        }
        .onChange(of: settings.terminalFontSize) { _ in settings.save() }
        .onChange(of: settings.terminalScrollback) { _ in settings.save() }
    }
}

struct KeyboardSettingsSection: View {
    @StateObject private var shortcutsService = KeyboardShortcutsService()
    @State private var editingAction: String? = nil
    @State private var editingValue: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader("Shortcuts")
            
            ForEach(shortcutsService.shortcuts.sorted(by: { $0.key < $1.key }), id: \.key) { action, shortcut in
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
