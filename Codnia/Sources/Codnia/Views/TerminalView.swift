import SwiftUI
import SwiftTerm

struct TerminalView: View {
    let tab: Tab
    @EnvironmentObject var terminalVM: TerminalViewModel

    var body: some View {
        TerminalRepresentable(
            terminalId: tab.terminalId ?? "",
            onInput: { data in
                terminalVM.writeToTerminal(id: tab.id, data: data)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}

struct TerminalRepresentable: NSViewRepresentable {
    let terminalId: String
    let onInput: (String) -> Void

    func makeNSView(context: Context) -> TerminalViewNS {
        let view = TerminalViewNS()
        view.setup(terminalId: terminalId, onInput: onInput)
        return view
    }

    func updateNSView(_ nsView: TerminalViewNS, context: Context) {
        // Updates handled internally
    }
}

class TerminalViewNS: NSView {
    private var terminal: LocalProcessTerminalView?
    private var onInputHandler: ((String) -> Void)?
    private var processTask: Process?

    func setup(terminalId: String, onInput: @escaping (String) -> Void) {
        onInputHandler = onInput

        let localTerminal = LocalProcessTerminalView()
        localTerminal.nativeBackgroundColor = NSColor(Color.bgPrimary)
        localTerminal.nativeForegroundColor = NSColor(Color.textPrimary)
        let font = NSFont(name: "SF Mono", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        localTerminal.font = font

        self.terminal = localTerminal
        self.addSubview(localTerminal)
        localTerminal.translatesAutoresizingMaskIntoConstraints = false
        localTerminal.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        localTerminal.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        localTerminal.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        localTerminal.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true

        // Start local process
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-l"]
        task.environment = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        let path = ["/usr/local/bin", "/opt/homebrew/bin", "\(home)/.local/bin", "/usr/bin", "/bin"].joined(separator: ":")
        task.environment?["PATH"] = path
        task.currentDirectoryURL = URL(fileURLWithPath: home)

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        task.standardInput = inputPipe
        task.standardOutput = outputPipe
        task.standardError = outputPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak localTerminal] handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    localTerminal?.feed(text: str)
                }
            }
        }

        localTerminal.feedProc = { [weak inputPipe] data in
            if let d = data.data(using: .utf8) {
                inputPipe?.fileHandleForWriting.write(d)
            }
        }

        self.processTask = task

        do {
            try task.run()
        } catch {
            print("Failed to start terminal: \(error)")
        }
    }

    override func layout() {
        super.layout()
        terminal?.frame = self.bounds
    }
}
