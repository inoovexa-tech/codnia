import SwiftUI

struct BrowserStorageView: View {
    @ObservedObject var devToolsService: BrowserDevToolsService
    @State private var selectedType: BrowserStorageEntry.StorageType = .localStorage

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
            Button(action: { devToolsService.refreshStorage() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
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
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.bgTertiary)

                ForEach(filtered) { entry in
                    StorageEntryRow(entry: entry)
                    Divider()
                        .background(Color.borderDefault.opacity(0.3))
                }
            }
        }
        .background(Color.bgPrimary)
    }
}

struct StorageEntryRow: View {
    let entry: BrowserStorageEntry
    @State private var showFullValue: Bool = false

    var body: some View {
        Button(action: { withAnimation { showFullValue.toggle() } }) {
            HStack(spacing: 8) {
                Text(entry.key)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.accentBlue)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(showFullValue ? entry.value : truncateValue(entry.value))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .lineLimit(showFullValue ? nil : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func truncateValue(_ value: String) -> String {
        if value.count > 120 { return String(value.prefix(120)) + "..." }
        return value
    }
}
