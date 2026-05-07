# Codnia

A modern, lightweight desktop IDE built with Swift and SwiftUI for macOS.

![Version](https://img.shields.io/badge/version-0.1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20macOS%20%7C%20macOS-lightgrey)

## Features

### Editor
- **Monaco Editor** with custom "codnia-dark" theme (pure-black background)
- Syntax highlighting for **20+ languages** (Rust, TypeScript, JavaScript, Python, Go, Java, C/C++, C#, Swift, Kotlin, Ruby, HTML, CSS, SCSS, Markdown, YAML, TOML, Shell, and more)
- File model caching, Save / Save As, modified indicators
- Configurable font, minimap, line numbers, word wrap, tab size, whitespace rendering

### Terminal
- **Native PTY** via portable-pty with real shell spawning
- xterm.js rendering with ANSI 256-color support
- Multiple terminal instances in separate tabs
- Custom shell and command execution support

### AI Agent Integration
- Built-in terminal tabs for **OpenCode**, **Claude Code**, and **Codex**
- One-click launch from the New Tab dropdown
- Missing tool detection with install guidance

### Search
- **ripgrep-powered** global search with regex and case-sensitive toggles
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
- Separate settings window with four tabs: Editor, Appearance, Terminal, Keyboard
- 11 rebindable keyboard shortcuts with recording input
- Persistent settings with cross-window sync

### Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| `Cmd/Ctrl+N` | New File |
| `Cmd/Ctrl+O` | Open File |
| `Cmd/Ctrl+S` | Save |
| `Cmd/Ctrl+Shift+S` | Save As |
| `Cmd/Ctrl+W` | Close Tab |
| `Cmd/Ctrl+B` | Toggle Sidebar |
| `Cmd/Ctrl+`` ` | Toggle Terminal |
| `Cmd/Ctrl+Shift+F` | Global Search |
| `Cmd/Ctrl+Shift+O` | Run OpenCode |
| `Cmd/Ctrl+Shift+C` | Run Claude Code |
| `Cmd/Ctrl+Shift+X` | Run Codex |
| `Cmd/Ctrl+,` | Open Settings |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Desktop framework | **SwiftUI** (macOS 13+) |
| Language | **Swift 5.9+** |
| Code editor | **Monaco Editor** (via WKWebView) |
| Terminal | **xterm.js** + **portable-pty** |
| Build | **Swift Package Manager** |

## Getting Started

### Prerequisites

- [Xcode](https://developer.apple.com/xcode/) (15+)
- [Rust](https://rustup.rs/) (stable) - for portable-pty
- Platform-specific build tools (macOS SDK)

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
│       ├── App/           # App entry point and configuration
│       ├── Views/        # SwiftUI views
│       ├── ViewModels/   # ObservableObject classes
│       ├── Services/    # Business logic services
│       └── Models/       # Data models
├── Resources/            # App resources
├── Package.swift        # Swift Package Manager config
└── README.md
```

## Contributing

Contributions are welcome! Please follow this process:

1. **Create an Issue** - Report bugs, errors, or suggest new features.
2. **Issue Approval** - The issue will be reviewed and approved for development.
3. **Development** - Develop the fix/feature in a dedicated branch.
4. **Pull Request** - Submit your changes to the `main` branch.
5. **PR Approval** - The pull request will be reviewed and approved.
6. **Release** - Once approved, the changes will be included in the next version.

## License

This project is licensed under the [MIT License](LICENSE).