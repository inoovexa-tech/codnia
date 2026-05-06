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
