## [0.6.1] — 2026-05-08

### Fixed
- Fix Add Project button not opening folder picker on macOS
  - Replace `NSOpenPanel().runModal()` with SwiftUI `.fileImporter()` modifier
  - Applies to both expanded and collapsed sidebar layouts

## [0.6.0] — 2026-05-08

### Added
- Source Control panel in right sidebar with diff viewer
- Markdown preview toggle with full text selection
- Project switching with Cmd+Up/Down keyboard shortcuts

### Fixed
- Make add project button area fully clickable
- Close pipe write end to unblock git changes counting and prevent deadlock on stderr
- Skip runtime icon assignment in .app bundle to preserve Dock rounded corners
- Load app icon from SPM resource bundle for proper Dock display
- Restore double-click to zoom window on title bar drag area

## [0.5.1] — 2026-05-07

### Fixed
- Eliminate app hangs caused by thread starvation in GitService
  - Replace `waitUntilExit()` with `terminationHandler` + `async/await` — threads no longer block waiting for git processes
  - Run diff, staged, and untracked git commands concurrently instead of sequentially
  - Add cancellable `Task` management in `WorkspaceService` to prevent stale git requests from piling up
  - Replace `Timer`-based auto-refresh with `Task.sleep` to avoid spawning unbounded background threads

## [0.5.0] — 2026-05-07

### Added
- Syntax highlighting in code editor
- Black background theme for editor
- Tab reordering via drag-and-drop

### Fixed
- Prevent app hang on termination by stopping auto-refresh timer and file observers
- Enable smooth window drag without conflict with tab interactions

## [0.4.0] — 2026-05-07

### Added
- Project icon picker with auto-detection and custom upload

### Fixed
- Forward mouse scroll wheel to TUI apps as mouse button events
- Improve git changes count accuracy with numstat and real-time observers

## [0.3.0] — 2026-05-07

### Added
- Auto-save with 2-second debounce after typing stops
- Resizable sidebar with persisted widths (file explorer and right panel)
- Show hidden files toggle in file explorer

### Fixed
- Save editor content when switching tabs
- Disable window drag from content area, add dedicated drag area in tab bar
- Fix right sidebar resizable divider width updates

## [0.2.0] — 2026-05-06

### Added
- Rename project modal with option to rename directory
- Git changes count (+/-) displayed with green/red colors in sidebar and status bar
- Auto-refresh git changes every 3 seconds via WorkspaceService timer
- Persist editor tabs state per project (fileTabs, terminalTabs, activeTabId)
- Double-click on title bar to zoom/maximize window
- Improved terminal tab identification (type + index + directory)
- Auto-refresh file explorer and show hidden files

### Fixed
- Sidebar project row styling (active: gray bg, inactive: no bg, active icon: blue)
- AttributeGraph cycle issues resolved by using timer-based updates instead of computed properties
- Rename project now properly updates sidebar UI
- Git changes aligned to the right of branch name

## [0.1.1] — 2026-05-06

### Fixed
- Terminal sessions now persist across tab switches and project changes
- TerminalManager keeps instances alive globally, only hiding/showing based on active tab
- Fixed terminal process being killed when switching between projects
- Added TerminalContainerManager for persistent NSView container across SwiftUI recreation

### Added
- Keyboard shortcuts: Cmd+N (new file), Cmd+T (new terminal), Cmd+S (save), Cmd+Shift+S (save as), Cmd+W (close tab)
- Keyboard shortcut hints in TabBarView "+" menu

## [0.1.0] — 2026-05-06

### Added
- Initial release of Codnia IDE
- Swift/SwiftUI macOS native application
- Code editor with syntax highlighting via SwiftTerm
- File tree navigation and project management
- Tab-based editing interface
- Terminal integration
- Settings panel
- Application icon
- macOS 13 (Ventura) minimum support

### Fixed
- Terminal typing issues in release/DMG builds
- Removed duplicate terminal process creation in TerminalService
- Fixed environment variables (LANG, TERM, HOME) for LocalProcessTerminalView
- Improved first responder handling with Coordinator pattern
- Added Info.plist for proper app bundle configuration
