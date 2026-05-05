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
