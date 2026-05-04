## [0.2.0] — 2026-05-04

### Fixed
- Terminal now inherits user's full PATH (Homebrew, nvm, cargo, pnpm, local bins) so commands like `opencode` are found correctly
- Terminal shell launched as login shell (`-l` flag) so `~/.zshrc` / `~/.zprofile` are sourced
- macOS DMG no longer shows "app is damaged" Gatekeeper warning — ad-hoc code signing and entitlements added

### Added
- Right-click context menu on sidebar projects with "Rename" and "Remove" options
- `rename_project` Tauri command and frontend binding
- `Codnia.entitlements` for macOS signing (JIT, unsigned memory, dyld env vars, library validation)

## [0.1.0] — 2026-05-02

### Added
- Initial public release of Codnia IDE