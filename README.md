# Codnia

A modern, lightweight desktop IDE built with Tauri v2, React 19, and Rust.

![Version](https://img.shields.io/badge/version-0.1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux-lightgrey)

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

### Plugin System & Marketplace
- Plugin discovery, activation, and lifecycle management
- TOML-based plugin manifests
- Built-in marketplace with categories and search
- Install, uninstall, and publish plugins

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
| Desktop framework | **Tauri v2** (Rust) |
| Frontend | **React 19** + **TypeScript** |
| Styling | **Tailwind CSS 4** + **shadcn/ui** (new-york) |
| Code editor | **Monaco Editor** 0.52 |
| Terminal | **xterm.js** 6.0 + **portable-pty** |
| Search | **ripgrep** (with WalkDir fallback) |
| Markdown | **pulldown-cmark** (GFM) |
| Build | **Vite** 6 |

## Getting Started

### Prerequisites

- [Rust](https://rustup.rs/) (stable)
- [Node.js](https://nodejs.org/) (18+)
- Platform-specific Tauri dependencies (see [Tauri docs](https://v2.tauri.app/start/prerequisites/))

### Development

```bash
# Install frontend dependencies
cd frontend && npm install

# Run in development mode (Tauri dev server on port 3030)
cd ../src-tauri && cargo tauri dev
```

### Build

```bash
# macOS
cd src-tauri && cargo tauri build

# Windows (from Windows, or with cross-compile toolchain)
cd src-tauri && cargo tauri build --target x86_64-pc-windows-msvc

# Linux (from Linux, or with cross-compile toolchain)
cd src-tauri && cargo tauri build --target x86_64-unknown-linux-gnu
```

Build outputs:
- **macOS**: `src-tauri/target/release/bundle/macos/Codnia.app` and `.dmg`
- **Windows**: `src-tauri/target/release/bundle/msi/` and `.exe`
- **Linux**: `src-tauri/target/release/bundle/deb/` and `.appimage`

### Project Structure

```
codnia/
├── frontend/            # Vite + React 19 + Tailwind CSS 4
│   ├── src/
│   │   ├── components/  # UI components (file-tree, terminal, sidebar, etc.)
│   │   ├── hooks/       # React hooks (use-editor, use-workspace, use-settings)
│   │   ├── lib/         # Utilities and Tauri API wrappers
│   │   └── types/       # TypeScript types
│   ├── index.html       # Main IDE entry point
│   └── settings.html    # Settings window entry point
├── src-tauri/           # Tauri v2 Rust backend
│   ├── src/
│   │   ├── main.rs      # App entry, commands, menu setup
│   │   └── core/        # Business logic modules
│   │       ├── workspace.rs
│   │       ├── file_system.rs
│   │       ├── terminal.rs
│   │       ├── search.rs
│   │       ├── preview.rs
│   │       ├── plugins/
│   │       ├── marketplace.rs
│   │       ├── settings.rs
│   │       └── persistence.rs
│   └── icons/           # App icons (ICNS, ICO, PNG)
├── CHANGELOG.md
├── LICENSE
└── README.md
```

## License

This project is licensed under the [MIT License](LICENSE).