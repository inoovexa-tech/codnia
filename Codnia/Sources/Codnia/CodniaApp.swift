import SwiftUI

@main
struct CodniaApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CodniaCommands(
                newFile: { appState.editorVM.newFile() },
                openFile: { appState.editorVM.openFileDialog() },
                save: { appState.editorVM.saveCurrentFile() },
                saveAs: { appState.editorVM.saveCurrentFileAs() },
                closeTab: { appState.editorVM.closeCurrentTab() },
                toggleSidebar: { appState.workspaceVM.toggleSidebar() },
                toggleTerminal: { appState.editorVM.createTerminalTab() },
                globalSearch: {
                    appState.editorVM.showGlobalSearch = true
                }
            )
        }
    }
}

struct CodniaCommands: Commands {
    let newFile: () -> Void
    let openFile: () -> Void
    let save: () -> Void
    let saveAs: () -> Void
    let closeTab: () -> Void
    let toggleSidebar: () -> Void
    let toggleTerminal: () -> Void
    let globalSearch: () -> Void

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New File") { newFile() }
                .keyboardShortcut("n", modifiers: .command)
            Button("Open File...") { openFile() }
                .keyboardShortcut("o", modifiers: .command)
            Divider()
            Button("Save") { save() }
                .keyboardShortcut("s", modifiers: .command)
            Button("Save As...") { saveAs() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Divider()
            Button("Close Tab") { closeTab() }
                .keyboardShortcut("w", modifiers: .command)
        }

        CommandMenu("View") {
            Button("Toggle Sidebar") { toggleSidebar() }
                .keyboardShortcut("b", modifiers: .command)
            Button("Toggle Terminal") { toggleTerminal() }
                .keyboardShortcut("`", modifiers: .command)
            Button("Global Search") { globalSearch() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
        }
    }
}
