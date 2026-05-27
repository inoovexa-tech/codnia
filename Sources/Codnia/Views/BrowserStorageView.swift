import SwiftUI

struct BrowserStorageView: View {
    @ObservedObject var devToolsService: BrowserDevToolsService
    @State private var selectedType: BrowserStorageEntry.StorageType = .localStorage
    @State private var editingKey: String? = nil
    @State private var editingValue: String = ""
    @State private var newKey: String = ""
    @State private var newValue: String = ""
    @State private var showAddRow: Bool = false
    @State private var confirmClear: Bool = false

    private var filtered: [BrowserStorageEntry] {
        devToolsService.storageEntries.filter { $0.type == selectedType }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            typePicker
            if devToolsService.isStorageLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: .textSecondary))
                Spacer()
            } else if filtered.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            Text("Storage")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textSecondary)
            Spacer()

            Button(action: { showAddRow.toggle() }) {
                Image(systemName: "plus")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.accentBlue)
            .help("Add item")

            Button(action: { confirmClear = true }) {
                Image(systemName: "trash.slash")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.accentRed)
            .help("Clear all")
            .alert("Clear all \(selectedType.rawValue.lowercased())?", isPresented: $confirmClear) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    let typeStr: String
                    switch selectedType {
                    case .localStorage: typeStr = "localStorage"
                    case .sessionStorage: typeStr = "sessionStorage"
                    case .cookies: typeStr = "cookies"
                    }
                    devToolsService.clearStorage(type: typeStr)
                }
            } message: {
                Text("This will remove all \(selectedType.rawValue.lowercased()) entries for this site.")
            }

            Button(action: { devToolsService.refreshStorage() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
            .help("Refresh storage data")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
    }

    private var typePicker: some View {
        HStack(spacing: 0) {
            ForEach(BrowserStorageEntry.StorageType.allCases, id: \.self) { type in
                Button(action: { selectedType = type }) {
                    Text(type.rawValue)
                        .font(.system(size: 10))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundColor(selectedType == type ? .accentBlue : .textSecondary)
                        .background(selectedType == type ? Color.accentBlue.opacity(0.1) : Color.clear)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "externaldrive")
                .font(.system(size: 20))
                .foregroundColor(.textTertiary)
            Text("No \(selectedType.rawValue.lowercased()) entries")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
            Button("Refresh") { devToolsService.refreshStorage() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.accentBlue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text("Key")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Value")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Actions")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.textSecondary)
                        .frame(width: 50, alignment: .center)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.bgTertiary)

                if showAddRow {
                    addRowView
                }

                ForEach(filtered) { entry in
                    StorageEntryRow(
                        entry: entry,
                        isEditing: editingKey == "\(entry.type.rawValue):\(entry.key)",
                        editValue: Binding(
                            get: { editingKey == "\(entry.type.rawValue):\(entry.key)" ? editingValue : entry.value },
                            set: { editingValue = $0 }
                        ),
                        onStartEdit: {
                            editingKey = "\(entry.type.rawValue):\(entry.key)"
                            editingValue = entry.value
                        },
                        onCommitEdit: {
                            let typeStr: String
                            switch entry.type {
                            case .localStorage: typeStr = "localStorage"
                            case .sessionStorage: typeStr = "sessionStorage"
                            case .cookies: typeStr = "cookie"
                            }
                            devToolsService.setStorageItem(type: typeStr, key: entry.key, value: editingValue)
                            editingKey = nil
                        },
                        onCancelEdit: {
                            editingKey = nil
                        },
                        onDelete: {
                            let typeStr: String
                            switch entry.type {
                            case .localStorage: typeStr = "localStorage"
                            case .sessionStorage: typeStr = "sessionStorage"
                            case .cookies: typeStr = "cookie"
                            }
                            devToolsService.removeStorageItem(type: typeStr, key: entry.key)
                        }
                    )
                    Divider()
                        .background(Color.borderDefault.opacity(0.3))
                }
            }
        }
        .background(Color.bgPrimary)
    }

    private var addRowView: some View {
        HStack(spacing: 4) {
            TextField("Key", text: $newKey)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.accentBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("Value", text: $newValue)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 2) {
                Button(action: {
                    guard !newKey.isEmpty else { return }
                    let typeStr: String
                    switch selectedType {
                    case .localStorage: typeStr = "localStorage"
                    case .sessionStorage: typeStr = "sessionStorage"
                    case .cookies: typeStr = "cookie"
                    }
                    devToolsService.setStorageItem(type: typeStr, key: newKey, value: newValue)
                    newKey = ""
                    newValue = ""
                    showAddRow = false
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8))
                        .frame(width: 16, height: 16)
                        .foregroundColor(.accentGreen)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(newKey.isEmpty)

                Button(action: {
                    newKey = ""
                    newValue = ""
                    showAddRow = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .frame(width: 16, height: 16)
                        .foregroundColor(.accentRed)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 50, alignment: .center)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentGreen.opacity(0.05))
    }
}

struct StorageEntryRow: View {
    let entry: BrowserStorageEntry
    let isEditing: Bool
    @Binding var editValue: String
    let onStartEdit: () -> Void
    let onCommitEdit: () -> Void
    let onCancelEdit: () -> Void
    let onDelete: () -> Void

    @State private var showFullValue: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if isEditing {
                TextField("Value", text: $editValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onSubmit { onCommitEdit() }
            } else {
                Text(entry.key)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.accentBlue)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(showFullValue ? entry.value : truncateValue(entry.value))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .lineLimit(showFullValue ? nil : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .onTapGesture(count: 2) {
                        onStartEdit()
                    }
            }

            HStack(spacing: 2) {
                if !isEditing {
                    Button(action: onStartEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 7))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.accentBlue)
                    .help("Edit value (double-click)")

                    Button(action: { showFullValue.toggle() }) {
                        Image(systemName: showFullValue ? "chevron.up" : "chevron.down")
                            .font(.system(size: 7))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.textTertiary)
                    .help(showFullValue ? "Collapse" : "Expand")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 7))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.accentRed)
                    .help("Delete item")
                } else {
                    Button(action: onCommitEdit) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.accentGreen)
                    .help("Save")

                    Button(action: onCancelEdit) {
                        Image(systemName: "xmark")
                            .font(.system(size: 7))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.accentRed)
                    .help("Cancel")
                }
            }
            .frame(width: 50, alignment: .center)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isEditing ? Color.accentBlue.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
    }

    private func truncateValue(_ value: String) -> String {
        if value.count > 120 { return String(value.prefix(120)) + "..." }
        return value
    }
}
