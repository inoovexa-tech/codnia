import SwiftUI
import AppKit

@MainActor
class CodniaApplicationDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    lazy var appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        if let icon = NSImage(contentsOfFile: Bundle.main.path(forResource: "icon", ofType: "png") ?? "") {
            NSApp.applicationIconImage = icon
        }

        let contentView = ContentView()
            .environmentObject(appState)
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
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true

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
}

@main
struct CodniaApp: App {
    @NSApplicationDelegateAdaptor(CodniaApplicationDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState.settings)
                .frame(minWidth: 700, minHeight: 540)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New File") { appDelegate.appState.editorVM.newFile() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("New Terminal") { appDelegate.appState.editorVM.createTerminalTab(type: .terminal) }
                    .keyboardShortcut("t", modifiers: .command)
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
                    appDelegate.appState.leftSidebarExpanded.toggle()
                }
                .keyboardShortcut("b", modifiers: .command)
                Button("Toggle Terminal") {
                    if let tab = appDelegate.appState.terminalVM.tabs.first {
                        appDelegate.appState.editorVM.activeTabId = tab.id
                    } else {
                        appDelegate.appState.editorVM.createTerminalTab(type: .terminal)
                    }
                }
                .keyboardShortcut("`", modifiers: .command)
                Button("Global Search") {
                    let state = appDelegate.appState
                    if state.rightSidebarExpanded && state.rightSidebarTab == .search {
                        state.rightSidebarExpanded = false
                        state.editorVM.showGlobalSearch = false
                    } else {
                        state.rightSidebarTab = .search
                        state.rightSidebarExpanded = true
                        state.editorVM.showGlobalSearch = true
                    }
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
    }
}


