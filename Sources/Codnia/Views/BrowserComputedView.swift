import SwiftUI

struct BrowserComputedView: View {
    @ObservedObject var devToolsService: BrowserDevToolsService
    @State private var filterText: String = ""

    private var filteredProperties: [(String, String)] {
        guard let props = devToolsService.computedStyle?.properties else { return [] }
        if filterText.isEmpty {
            return props.sorted { $0.key < $1.key }
        }
        return props.filter { $0.key.localizedCaseInsensitiveContains(filterText) || $0.value.localizedCaseInsensitiveContains(filterText) }
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text("Computed")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()
                TextField("Filter", text: $filterText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .frame(width: 120)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.bgTertiary)
                    .cornerRadius(3)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.bgSecondary)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)

            if devToolsService.computedStyle == nil {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredProperties), id: \.0) { key, value in
                            HStack(spacing: 4) {
                                Text(key)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.accentRed)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(value)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.textPrimary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.bgPrimary)

                            Divider()
                                .background(Color.borderDefault.opacity(0.15))
                        }

                        if let box = devToolsService.computedStyle?.boxModel {
                            Divider()
                                .background(Color.borderDefault)
                            BoxModelView(box: box)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 20))
                .foregroundColor(.textTertiary)
            Text("No computed styles available")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
            Text("Select an element in the Elements panel")
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BoxModelView: View {
    let box: BrowserBoxModel

    var body: some View {
        VStack(spacing: 2) {
            Text("Box Model")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.textSecondary)
                .padding(.top, 4)

            boxSection(label: "margin", values: box.margin, color: .accentYellow)
            HStack(spacing: 2) {
                boxSideLabel(box.margin.left, color: .accentYellow)
                boxSection(label: "border", values: box.border, color: .accentOrange)
                boxSideLabel(box.margin.right, color: .accentYellow)
            }
            HStack(spacing: 2) {
                boxSideLabel(box.border.left, color: .accentOrange)
                boxSection(label: "padding", values: box.padding, color: .accentGreen)
                boxSideLabel(box.border.right, color: .accentOrange)
            }
            HStack(spacing: 2) {
                boxSideLabel(box.padding.left, color: .accentGreen)
                Text("\(Int(box.content.width)) x \(Int(box.content.height))")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.accentBlue)
                    .padding(6)
                    .background(Color.accentBlue.opacity(0.1))
                    .cornerRadius(3)
                boxSideLabel(box.padding.right, color: .accentGreen)
            }
            HStack(spacing: 2) {
                boxSideLabel(box.border.left, color: .accentOrange)
                boxSideLabel(box.border.right, color: .accentOrange)
            }
            HStack(spacing: 2) {
                boxSideLabel(box.margin.left, color: .accentYellow)
                boxSideLabel(box.margin.right, color: .accentYellow)
            }
            boxSection(label: "margin", values: box.margin, color: .accentYellow)
        }
        .padding(6)
        .background(Color.bgTertiary.opacity(0.3))
        .cornerRadius(4)
        .padding(4)
    }

    private func boxSection(label: String, values: BrowserBoxModel.EdgeInsets, color: Color) -> some View {
        HStack(spacing: 2) {
            boxValueLabel(values.left, color: color)
            Text(label)
                .font(.system(size: 7))
                .foregroundColor(color)
                .frame(width: 40)
            boxValueLabel(values.right, color: color)
        }
    }

    private func boxValueLabel(_ value: String, color: Color) -> some View {
        Text(value)
            .font(.system(size: 7, design: .monospaced))
            .foregroundColor(color)
            .frame(width: 50)
            .lineLimit(1)
    }

    private func boxSideLabel(_ value: String, color: Color) -> some View {
        Text(value)
            .font(.system(size: 7, design: .monospaced))
            .foregroundColor(color)
            .frame(width: 50)
            .lineLimit(1)
    }
}
