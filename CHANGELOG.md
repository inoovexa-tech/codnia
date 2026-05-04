## [0.2.2] — 2026-05-04

### Fixed
- Terminal output batching via mpsc channel — PTY reads are now coalesced before emitting to the frontend, reducing IPC overhead by ~10-50x for TUI apps like opencode
- Significantly faster terminal rendering in release builds — small escape sequences are batched into fewer events instead of flooding the frontend

## [0.2.1] — 2026-05-04

### Fixed
- Terminal no longer duplicates/triples characters when typing — removed React.StrictMode and fixed effect lifecycle to prevent double-mounting xterm instances
- Terminal processes (opencode, etc.) no longer crash when switching tabs — useEffect now depends only on terminalId
- PTY reader thread optimized — event names pre-computed, UTF-8 fast path avoids unnecessary allocations
- xterm instance properly disposed on unmount, preventing memory leaks
- File tree rename now correctly computes parent path for directories (was nesting renamed dir inside itself)
- Project rename now shows a proper modal dialog instead of broken `window.prompt` (which doesn't work in Tauri native windows)
- Rename modal uses inline styles via createPortal to ensure correct spacing regardless of sidebar overflow/width constraints

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