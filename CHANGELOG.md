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
