import SwiftUI

struct BrowserConsoleView: View {
    @ObservedObject var devToolsService: BrowserDevToolsService
    @State private var jsInput: String = ""
    @State private var searchText: String = ""
    @State private var jsHistory: [String] = []
    @State private var historyIndex: Int = -1
    @State private var showSearch: Bool = false
    @State private var showOptions: Bool = false
    @FocusState private var inputFocused: Bool
    @FocusState private var searchFocused: Bool

    private var filteredEntries: [BrowserConsoleEntry] {
        var result = devToolsService.filteredEntries
        if !searchText.isEmpty {
            result = result.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            consoleToolbar
            if showSearch {
                searchBar
            }
            logList
            jsInputBar
        }
    }

    private var consoleToolbar: some View {
        HStack(spacing: 4) {
            Text("Console")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(BrowserDevToolsService.ConsoleFilter.allCases, id: \.self) { filter in
                        Button(action: { devToolsService.consoleFilter = filter }) {
                            Text(filter.rawValue)
                                .font(.system(size: 9))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .foregroundColor(devToolsService.consoleFilter == filter ? .accentBlue : .textTertiary)
                                .background(devToolsService.consoleFilter == filter ? Color.accentBlue.opacity(0.12) : Color.clear)
                                .cornerRadius(3)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(maxWidth: 120)

            Spacer()

            Button(action: { showSearch.toggle(); if showSearch { searchFocused = true } else { searchText = "" } }) {
                Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
            .help("Search")

            Button(action: { showOptions.toggle() }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(showOptions ? .accentBlue : .textTertiary)
            .help("Options")
            .popover(isPresented: $showOptions, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $devToolsService.preserveConsoleLog) {
                        Text("Preserve log")
                            .font(.system(size: 11))
                    }
                    .toggleStyle(.checkbox)
                    Toggle(isOn: $devToolsService.showRelativeTimestamps) {
                        Text("Relative timestamps")
                            .font(.system(size: 11))
                    }
                    .toggleStyle(.checkbox)
                }
                .padding(10)
                .frame(width: 170)
            }

            Text("\(filteredEntries.count) entries")
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)

            Button(action: { devToolsService.clearConsole() }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
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

    private var searchBar: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
            TextField("Filter console output...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.textPrimary)
                .focused($searchFocused)
            Button(action: { searchText = "" }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.bgTertiary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredEntries) { entry in
                        ConsoleEntryRow(entry: entry, devToolsService: devToolsService, useRelativeTime: devToolsService.showRelativeTimestamps)
                            .id(entry.id)
                        Divider()
                            .background(Color.borderDefault.opacity(0.3))
                    }
                }
            }
            .background(Color.bgPrimary)
            .onChange(of: filteredEntries.count) { _ in
                if let last = filteredEntries.last {
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

            TextField("JavaScript expression... (⌥Enter for new line, ↑↓ for history)", text: $jsInput, axis: .vertical)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.textPrimary)
                .focused($inputFocused)
                .lineLimit(1...10)
                .onSubmit {
                    executeJS()
                }
                .onExitCommand {
                    inputFocused = false
                }

            Button(action: { executeJS() }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 9))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.accentGreen)
            .help("Execute (Enter)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .top)
    }

    private func executeJS() {
        let code = jsInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        devToolsService.evaluateJS(code)
        if jsHistory.first != code {
            jsHistory.insert(code, at: 0)
        }
        historyIndex = -1
        jsInput = ""
    }
}

struct ConsoleEntryRow: View {
    let entry: BrowserConsoleEntry
    let devToolsService: BrowserDevToolsService
    let useRelativeTime: Bool

    @State private var showStack: Bool = false
    @State private var showArgs: Bool = false

    private var relativeTimeString: String {
        let interval = -entry.timestamp.timeIntervalSinceNow
        if interval < 1 { return "now" }
        if interval < 60 { return String(format: "%.0fs", interval) }
        if interval < 3600 { return String(format: "%.0fm", interval / 60) }
        return String(format: "%.1fh", interval / 3600)
    }

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
                Group {
                    if useRelativeTime {
                        Text(relativeTimeString)
                    } else {
                        Text(entry.timestamp, style: .time)
                    }
                }
                .font(.system(size: 9))
                .foregroundColor(.textTertiary)
                .help(entry.timestamp.formatted(date: .numeric, time: .complete))
            }
            if let args = entry.args, !args.isEmpty {
                if showArgs {
                    Button(action: { showArgs = false }) {
                        Text("\(args.count) argument(s) — hide")
                            .font(.system(size: 9))
                            .foregroundColor(.accentBlue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    ForEach(Array(args.enumerated()), id: \.offset) { idx, arg in
                        HStack(spacing: 4) {
                            Text("\(idx):")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.textTertiary)
                            if let objId = arg["objectId"] as? Int {
                                Button(action: { devToolsService.getConsoleObject(objId) }) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "arrow.triangle.branch")
                                            .font(.system(size: 7))
                                        Text("Object #\(objId)")
                                            .font(.system(size: 9, design: .monospaced))
                                    }
                                    .foregroundColor(.accentBlue)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                Text(arg["value"] as? String ?? "")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.textPrimary)
                            }
                        }
                        .padding(.leading, 12)
                    }
                } else {
                    Button(action: { showArgs = true }) {
                        Text("\(args.count) argument(s)")
                            .font(.system(size: 9))
                            .foregroundColor(.accentBlue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 12)
                }
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
