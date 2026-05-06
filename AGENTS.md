# Codnia — Agent Context

Repository layout
- Swift/SwiftUI macOS app (no frontend/ or src-tauri/)
- `Sources/Codnia/` — All Swift source code
- `Package.swift` — Swift package manager config

Developer commands
- `swift build` — Build the project
- `swift run` — Run the app
- No test, lint, or typecheck scripts exist. `swift build` is the only verification step.

Architecture
- `CodniaApp.swift` — NSApplicationDelegate, window setup
- `Views/` — SwiftUI views (ContentView, TabBarView, EditorAreaView, etc.)
- `ViewModels/` — ObservableObject classes (AppState, EditorViewModel, etc.)
- `Services/` — Business logic services
- `Models/` — Data models (Tab, FileEntry, Project, etc.)

Commit rules
- **ALL commit messages MUST be in English**
- Use conventional commit format: `type(scope): description`
- Types: fix, feat, refactor, docs, chore, etc.
- Keep descriptions concise and descriptive

Examples:
```
fix(ui): fix tab bar alignment with native title bar
feat(editor): add tab context menu for new file/terminal
fix(editor): prevent editor from disappearing when creating new file
```

Constraints
- macOS desktop app only (SwiftUI)
- Minimum macOS 13 (Ventura)

Release process
- Version format: `v0.0.0` (semantic versioning)
- Update `CHANGELOG.md` with the new version and date
- Build in release mode: `swift build --configuration release`
- Create app bundle structure:
  - `mkdir -p /tmp/codnia-app/Codnia.app/Contents/MacOS`
  - `mkdir -p /tmp/codnia-app/Codnia.app/Contents/Resources`
  - Copy executable: `cp .build/release/Codnia /tmp/codnia-app/Codnia.app/Contents/MacOS/Codnia`
  - Copy icon: `cp Sources/Codnia/icon.png /tmp/codnia-app/Codnia.app/Contents/Resources/icon.png`
  - Create `Info.plist` with version, icon, and bundle identifier
  - Set executable permission: `chmod +x /tmp/codnia-app/Codnia.app/Contents/MacOS/Codnia`
- Create DMG: `hdiutil create -volname Codnia -srcfolder /tmp/codnia-app -ov -format UDZO Codnia-v0.0.0.dmg`
- Create git tag: `git tag -a v0.0.0 -m "Release v0.0.0"` then `git push origin v0.0.0`
- Create GitHub release with DMG: `gh release create v0.0.0 Codnia-v0.0.0.dmg --title "v0.0.0" --notes "Release notes here"`
