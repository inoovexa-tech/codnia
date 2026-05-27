import SwiftUI

struct BrowserStylesView: View {
    @ObservedObject var devToolsService: BrowserDevToolsService

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text("Styles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()
                if devToolsService.isStylesLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.bgSecondary)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)

            if devToolsService.matchedStyles.isEmpty && devToolsService.computedStyle == nil {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(devToolsService.matchedStyles) { style in
                            StyleRuleRow(style: style)
                            Divider()
                                .background(Color.borderDefault.opacity(0.3))
                        }
                    }
                }
                .background(Color.bgPrimary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "paintbrush")
                .font(.system(size: 20))
                .foregroundColor(.textTertiary)
            Text("Select an element to inspect its styles")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StyleRuleRow: View {
    let style: BrowserCSSStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(style.selector)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentBlue)
                Spacer()
                Text(style.source)
                    .font(.system(size: 8))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            ForEach(Array(style.properties.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                HStack(spacing: 4) {
                    Text(key)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.accentRed)
                    Text(":")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.textTertiary)
                    Text(value)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.textPrimary)
                        .textSelection(.enabled)
                }
                .padding(.leading, 12)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.bgPrimary)
    }
}
