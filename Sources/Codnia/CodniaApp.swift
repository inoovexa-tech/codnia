import SwiftUI

@MainActor
class CodniaApplicationDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    lazy var appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        TerminalEventMonitor.shared.install()

        let isAppBundle = Bundle.main.bundlePath.hasSuffix(".app")
        if !isAppBundle {
            let icon: NSImage? = {
                let spmBundle = Bundle.main.bundleURL.appendingPathComponent("Codnia_Codnia.bundle")
                if let bundle = Bundle(url: spmBundle),
                   let image = bundle.image(forResource: "icon") {
                    return image
                }
                return Bundle.main.image(forResource: "icon")
            }()
            if let icon {
                NSApp.applicationIconImage = icon
            }
        }

        let contentView = ContentView()
            .environmentObject(appState)
            .environmentObject(appState.settings)
            .frame(minWidth: 900, minHeight: 600)

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 1200, height: 800)
        hostingView.wantsLayer = true

        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Codnia"
        window.contentView = hostingView
        window.minSize = NSSize(width: 900, height: 600)
        window.backgroundColor = NSColor(Color.bgPrimary)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = true
        window.isMovableByWindowBackground = false
        window.isMovable = false

        if let toolbar = window.toolbar {
            toolbar.isVisible = false
        }

        window.makeKeyAndOrderFront(nil)
        window.center()

        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.workspaceVM.stopAutoRefresh()
    }
}

@main
struct CodniaApp: App {
    @NSApplicationDelegateAdaptor(CodniaApplicationDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState.settings)
                .environmentObject(appDelegate.appState.pluginService)
                .frame(minWidth: 700, minHeight: 540)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New File") { appDelegate.appState.editorVM.newFile() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("New Terminal") { appDelegate.appState.editorVM.createTerminalTab(type: .terminal) }
                    .keyboardShortcut("t", modifiers: .command)
                Button("OpenCode") { appDelegate.appState.editorVM.createTerminalTab(type: .opencode) }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Claude Code") { appDelegate.appState.editorVM.createTerminalTab(type: .claude) }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Codex") { appDelegate.appState.editorVM.createTerminalTab(type: .codex) }
                    .keyboardShortcut("x", modifiers: [.command, .shift])
                Divider()
                Button("New SQL Query") { appDelegate.appState.editorVM.newQueryTab(connectionId: nil) }
                    .keyboardShortcut("q", modifiers: [.command, .shift])
                Divider()
                Button("Open File...") { appDelegate.appState.editorVM.openFileDialog() }
                    .keyboardShortcut("o", modifiers: .command)
                Divider()
                Button("Save") { appDelegate.appState.editorVM.saveCurrentFile() }
                    .keyboardShortcut("s", modifiers: .command)
                Button("Save As...") { appDelegate.appState.editorVM.saveCurrentFileAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Divider()
                Button("Close Tab") { appDelegate.appState.editorVM.closeCurrentTab() }
                    .keyboardShortcut("w", modifiers: .command)
            }

            CommandMenu("View") {
                Button("Toggle Sidebar") {
                    appDelegate.appState.settings.leftSidebarExpanded.toggle()
                }
                .keyboardShortcut("b", modifiers: .command)
                Button("Toggle Terminal") {
                    if let tab = appDelegate.appState.terminalVM.tabs.first {
                        appDelegate.appState.editorVM.activateTab(tab.id)
                    } else {
                        appDelegate.appState.editorVM.createTerminalTab(type: .terminal)
                    }
                }
                .keyboardShortcut("`", modifiers: .command)
                Button("Global Search") {
                    appDelegate.appState.showGlobalSearchModal.toggle()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                Button("Find in File") {
                    appDelegate.appState.editorVM.showInFileSearch.toggle()
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            CommandMenu("Window") {
                Button("Next Tab") { appDelegate.appState.editorVM.nextTab() }
                    .keyboardShortcut(.tab, modifiers: .control)
                Button("Previous Tab") { appDelegate.appState.editorVM.previousTab() }
                    .keyboardShortcut(.tab, modifiers: [.control, .shift])
                Divider()
                Button("Next Project") { appDelegate.appState.workspaceVM.nextProject() }
                    .keyboardShortcut(.downArrow, modifiers: .command)
                Button("Previous Project") { appDelegate.appState.workspaceVM.previousProject() }
                    .keyboardShortcut(.upArrow, modifiers: .command)
            }
        }
    }
}
