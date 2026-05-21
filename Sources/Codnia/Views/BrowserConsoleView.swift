import SwiftUI

struct BrowserConsoleView: View {
    @ObservedObject var devToolsService: BrowserDevToolsService
    @State private var jsInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            consoleToolbar
            logList
            jsInputBar
        }
    }

    private var consoleToolbar: some View {
        HStack(spacing: 4) {
            Text("Console")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textSecondary)
            Spacer()
            Text("\(devToolsService.entries.count) entries")
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
            Button(action: { devToolsService.clearConsole() }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
            .help("Clear console")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(devToolsService.entries) { entry in
                        ConsoleEntryRow(entry: entry, devToolsService: devToolsService)
                            .id(entry.id)
                        Divider()
                            .background(Color.borderDefault.opacity(0.3))
                    }
                }
            }
            .background(Color.bgPrimary)
            .onChange(of: devToolsService.entries.count) { _ in
                if let last = devToolsService.entries.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var jsInputBar: some View {
        HStack(spacing: 4) {
            Text(">")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.accentGreen)
            TextField("JavaScript expression...", text: $jsInput)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.textPrimary)
                .onSubmit {
                    let code = jsInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !code.isEmpty else { return }
                    devToolsService.evaluateJS(code)
                    jsInput = ""
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .top)
    }
}

struct ConsoleEntryRow: View {
    let entry: BrowserConsoleEntry
    let devToolsService: BrowserDevToolsService

    @State private var showStack: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(levelColor)
                    .frame(width: 5, height: 5)
                Text(levelLabel)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(levelColor)
                    .frame(width: 30, alignment: .leading)
                if let el = entry.elementInfo {
                    Button(action: {
                        devToolsService.navigateToElement(tag: el.tag, nodeId: el.nodeId, classes: el.classes)
                    }) {
                        Image(systemName: "target")
                            .font(.system(size: 8))
                            .foregroundColor(.accentBlue)
                            .frame(width: 14, height: 14)
                            .background(Color.accentBlue.opacity(0.12))
                            .cornerRadius(3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Reveal in Elements panel")
                }
                Text(entry.message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .lineLimit(showStack ? nil : 3)
                    .textSelection(.enabled)
                Spacer()
                Text(entry.timestamp, style: .time)
                    .font(.system(size: 9))
                    .foregroundColor(.textTertiary)
            }
            if let stack = entry.stack, !stack.isEmpty {
                if showStack {
                    Button(action: { showStack = false }) {
                        Text(stack)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.textTertiary)
                            .lineLimit(nil)
                            .textSelection(.enabled)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else if entry.level == .error || entry.level == .warn {
                    Button(action: { showStack = true }) {
                        Text("Show stack trace")
                            .font(.system(size: 9))
                            .foregroundColor(.accentBlue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(showStack ? Color.bgHover : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                showStack.toggle()
            }
        }
    }

    private var levelLabel: String {
        switch entry.level {
        case .log:   return "LOG"
        case .info:  return "INF"
        case .warn:  return "WRN"
        case .error: return "ERR"
        }
    }

    private var levelColor: Color {
        switch entry.level {
        case .log:   return .textPrimary
        case .info:  return .accentBlue
        case .warn:  return .accentYellow
        case .error: return .accentRed
        }
    }
}
