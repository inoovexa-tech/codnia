# Codnia

A modern, lightweight desktop IDE built with Swift and SwiftUI for macOS.

![Version](https://img.shields.io/badge/version-0.11.1-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)

![Screenshot](screenshot.png)

## Features

### Editor
- **Native NSTextView** editor with dark theme
- File model caching, Save / Save As, modified indicators
- Configurable font size

### Terminal
- **SwiftTerm** native terminal with real shell spawning
- Multiple terminal instances in separate tabs
- Custom shell and command execution support

### AI Agent Integration
- Built-in terminal tabs for **OpenCode**, **Claude Code**, and **Codex**
- One-click launch from the New Tab dropdown

### Search
- Global search with regex and case-sensitive toggles
- File name and content search with match highlighting
- Smart directory exclusion (node_modules, .git, target, dist, etc.)

### Workspace
- Multi-root workspace support
- Project sidebar with Git branch display
- Per-project tab state (editor + terminal tabs restored on switch)
- Recent projects list

### File Explorer
- Recursive tree view with lazy-loading
- Full CRUD: create, rename, delete, duplicate, copy, cut, paste
- Drag-and-drop support
- Inline rename and creation (F2, context menu)

### Preview
- Markdown rendering (GFM: tables, footnotes, task lists, strikethrough)
- HTML passthrough preview
- Auto-detect from file extension

### Settings
- Separate settings window with multiple tabs
- Rebindable keyboard shortcuts with recording input
- Persistent settings with cross-window sync

### Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| `Cmd+N` | New File |
| `Cmd+O` | Open File |
| `Cmd+S` | Save |
| `Cmd+Shift+S` | Save As |
| `Cmd+W` | Close Tab |
| `Cmd+B` | Toggle Sidebar |
| `` Cmd+` `` | Toggle Terminal |
| `Cmd+Shift+F` | Global Search |
| `Cmd+Shift+O` | Run OpenCode |
| `Cmd+Shift+C` | Run Claude Code |
| `Cmd+Shift+X` | Run Codex |
| `Cmd+,` | Open Settings |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Desktop framework | **SwiftUI** (macOS 13+) |
| Language | **Swift 5.9+** |
| Code editor | **NSTextView** (native) |
| Terminal | **SwiftTerm** |
| Build | **Swift Package Manager** |

## Getting Started

### Prerequisites

- [Xcode](https://developer.apple.com/xcode/) (15+)
- macOS 13 (Ventura) or later

### Development

```bash
# Build the project
swift build

# Run in development mode
swift run
```

### Build

```bash
# Release build
swift build --configuration release
```

Build output: `.build/release/Codnia`

### Project Structure

```
codnia/
├── Sources/
│   └── Codnia/
│       ├── CodniaApp.swift    # App entry point and configuration
│       ├── Views/             # SwiftUI views
│       ├── ViewModels/       # ObservableObject classes
│       ├── Services/         # Business logic services
│       ├── Models/           # Data models
│       ├── Components/       # Reusable UI components
│       ├── Extensions/       # Swift extensions
│       └── Resources/        # App resources
├── Package.swift             # Swift Package Manager config
└── README.md
```

## Creating a New Version

Follow these steps to create a new release:

1. **Retrieve the latest commits** since the last version:
   ```bash
   git log v<last-version>..HEAD --oneline
   ```

2. **Determine release type**:
   - **Patch** (`0.x.1`): Bug fixes only
   - **Minor** (`0.x.0`): New features (no breaking changes)
   - **Major** (`0.0.0`): Breaking changes

3. **Build and generate the DMG** with icon and Applications symlink:
   ```bash
   swift build --configuration release
   mkdir -p /tmp/Codnia-v&lt;version&gt;/Codnia.app/Contents/{MacOS,Resources}
   cp .build/release/Codnia /tmp/Codnia-v&lt;version&gt;/Codnia.app/Contents/MacOS/
   cp .build/release/Codnia_Codnia.bundle/icon.icns /tmp/Codnia-v&lt;version&gt;/Codnia.app/Contents/Resources/
   cp Info.plist /tmp/Codnia-v&lt;version&gt;/Codnia.app/Contents/
   # Create Applications symlink for drag-and-drop installation
   ln -s /Applications /tmp/Codnia-v&lt;version&gt;/Applications
   hdiutil create -volname "Codnia v&lt;version&gt;" -srcfolder /tmp/Codnia-v&lt;version&gt; -format UDZO Codnia-v&lt;version&gt;.dmg
   ```

4. **Update README and CHANGELOG**:
   - Update version badge in README.md
   - Add new version section in CHANGELOG.md with commit descriptions

5. **Create tag and release**:
   ```bash
   git tag -a v<version> -m "Release v<version>"
   git push origin v<version>
   gh release create v<version> --title "v<version>" --notes "<changelog内容>"
   gh release upload v<version> Codnia-v<version>.dmg --clobber
   ```

> **Note:** Always keep the changelog in `CHANGELOG.md` up to date.

## License

This project is licensed under the [MIT License](LICENSE).