# Changelog

All notable changes to Codnia will be documented in this file.

## [0.1.0] - 2026-05-04

### Workspace & Project Management
- Add, remove, and switch projects from the sidebar
- Multi-root workspace support — add multiple root folders to a single project
- Recent projects list (up to 10, with timestamps)
- Per-project tab state — editor and terminal tabs restored when switching projects
- Project sidebar with initial-letter icons, expand/collapse, and active highlight
- Git branch display per project in the sidebar

### File Explorer
- Recursive tree view with lazy-loading expand/collapse
- File and folder icons with type-specific colors
- Dotfiles/dotdirs hidden by default
- Native context menu: New File, New Folder, Rename, Delete, Duplicate, Copy, Cut, Paste
- Inline rename (F2 or context menu)
- Inline new file/folder creation
- Clipboard: copy, cut, paste operations
- Drag-and-drop file support
- Manual refresh button
- Hover quick-actions for folders (New File / New Folder buttons)

### File System Operations
- List directory (sorted dirs-first, alphabetically)
- Read, write, create, delete files and directories
- Rename/move files and folders
- Copy file and recursive directory copy
- Duplicate with auto-incrementing suffix
- Open in system explorer (Finder / Explorer / file manager)
- Binary file detection

### Code Editor (Monaco)
- Monaco Editor with custom "codnia-dark" theme (pure-black #000000)
- Syntax highlighting for 20+ languages: Rust, TypeScript, JavaScript, JSON, HTML, CSS, SCSS, Less, Markdown, TOML, YAML, Shell, Python, Ruby, Go, Java, C, C++, C#, Swift, Kotlin
- File model caching — re-opening a file reuses its Monaco model
- New Untitled file (in-memory)
- Save / Save As with native dialog
- Unsaved changes indicator on tabs
- Cursor position tracking (Ln/Col in status bar)
- Language detection shown in status bar
- Configurable: font size, font family, minimap, line numbers, word wrap, tab size, insert spaces, render whitespace
- Automatic layout on resize

### Terminal
- Native PTY via portable-pty with real shell spawning
- xterm.js rendering with ANSI color support and custom Codnia theme
- Real-time data streaming via Tauri events
- Terminal exit detection with "[Process exited]" message
- Multiple independent terminal instances in separate tabs
- Resize handling (ResizeObserver + PTY sync)
- Kill terminal (SIGKILL)
- Custom shell configuration in settings
- Custom command execution support
- Configurable scrollback buffer (default 10,000 lines)
- TERM=xterm-256color for color support

### AI Agent Terminal Tabs
- OpenCode tab (launches `opencode` in terminal)
- Claude Code tab (launches `claude` in terminal)
- Codex tab (launches `codex` in terminal)
- Tab-type specific icons and colors
- Missing tool alert via native dialog
- New Tab dropdown menu: Terminal, OpenCode, Claude Code, Codex, New File

### Search
- File name search (case-insensitive, fuzzy)
- Content search with matching line display
- Advanced search powered by ripgrep (fallback to WalkDir)
- Regex toggle (fixed-strings default, regexp mode available)
- Case-sensitive toggle
- Configurable max results
- Ignored directories: node_modules, .git, target, dist, .next, __pycache__, venv, build, vendor, etc.
- Search timing measurement
- Global Search UI with debounced input, grouped results by file, match highlighting
- File name and content result tabs
- Click-to-open search results
- Loading spinner and empty/no-results states

### Preview
- Markdown rendering via pulldown-cmark (GFM: tables, footnotes, strikethrough, task lists)
- HTML passthrough rendering
- Auto-detect preview type from file extension (.md, .html, .htm)
- Unknown type fallback wrapped in `<pre>` tags

### Plugin System
- Plugin discovery from `config_local_dir()/codnia/plugins`
- TOML manifest parsing (plugin info, permissions, commands)
- Activate / deactivate plugin lifecycle
- Execute plugin commands
- List all plugins with active state
- Install / uninstall plugins with directory management

### Marketplace
- Featured plugins list
- 6 categories: AI & Assistant, Git & VCS, Formatters & Linters, DevOps & Cloud, Productivity, Themes
- Search and filter marketplace plugins
- Install / uninstall marketplace plugins (persisted as .toml)
- Publish plugin flow

### Settings & Preferences
- Persistent settings (JSON at `config_local_dir()/codnia/settings.json`)
- Separate settings window (WebviewWindow, 900x680, centered)
- Tabbed settings UI: Editor, Appearance, Terminal, Keyboard
- Editor settings: minimap, line numbers, word wrap, tab size, insert spaces
- Appearance settings: font size, font family
- Terminal settings: shell path, font size
- 11 rebindable keyboard shortcuts with recording input
- Shortcut de-duplication on rebind
- Instant "Saved" indicator
- LocalStorage caching and cross-window settings sync via StorageEvent

### Keyboard Shortcuts
- Cmd/Ctrl+N: New File
- Cmd/Ctrl+O: Open File
- Cmd/Ctrl+S: Save
- Cmd/Ctrl+Shift+S: Save As
- Cmd/Ctrl+W: Close Tab
- Cmd/Ctrl+B: Toggle Sidebar
- Cmd/Ctrl+`: Toggle Terminal
- Cmd/Ctrl+Shift+F: Global Search
- Cmd/Ctrl+Shift+O: Run OpenCode
- Cmd/Ctrl+Shift+C: Run Claude Code
- Cmd/Ctrl+Shift+X: Run Codex
- Cmd/Ctrl+,: Open Settings
- F2: Rename file
- Delete: Delete file

### UI
- Left sidebar: project list with initials, expand/collapse (52px ↔ 220px), settings button
- Right sidebar / activity bar: 320px panel with Explorer and Search tabs
- Status bar: Git branch, problems count, indentation, encoding, language, cursor position
- Custom title bar with tab row and window controls
- Unified tab bar for editor and terminal tabs
- File type icons in tabs (15+ extensions)
- Empty state with "Open a file to start editing"
- macOS native traffic lights (overlay title bar)
- Windows/Linux custom window controls
- shadcn/ui components (new-york style): Button, Dialog, DropdownMenu, ScrollArea, Switch, Tabs
- Custom dark scrollbar styling
- Tailwind CSS 4 theme with full color palette and design tokens

### Menu System
- Native application menu bar: File, Edit, View
- File: New File, Open File, Save, Save As, Close Tab
- Edit: Undo, Redo, Cut, Copy, Paste, Select All
- View: Toggle Sidebar, Toggle Terminal, Global Search
- Menu event dispatching via Tauri events
- Native context menus in file tree
- tauri-plugin-dialog for native open/save/message dialogs

### Persistence
- Workspace state persistence (projects, tabs, expanded folders, recents)
- Config persistence (recent projects, last active project)
- Settings persistence (full schema)
- Startup state restoration (skips deleted paths)
- Plugin and marketplace install persistence

### Logging & Error Handling
- Daily rolling file log (tracing + tracing-appender)
- Non-blocking async log writer
- INFO level default
- Custom panic handler with structured logging
- Graceful command errors with descriptive messages

### Build & Distribution
- LTO and single codegen-unit for optimized release binary
- Panic=abort for reduced binary size
- Vite chunk splitting: Monaco, React, Radix UI
- macOS bundle (.app + .dmg)
- Multi-platform icon support (ICNS, ICO, PNG)