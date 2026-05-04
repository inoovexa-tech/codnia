# Plan: Codnia IDE Implementation

**Generated**: 2026-04-30
**Estimated Complexity**: High

## Overview

Codnia is an agent-first IDE built with Tauri (Rust) + Slint (UI) + Monaco (Editor). The implementation follows a phased approach starting from core infrastructure to full feature completion.

**Tech Stack:**
- Desktop Shell: Tauri 2.x
- UI Framework: Slint 1.x
- Code Editor: Monaco (WebView)
- Backend: Rust (100%)
- Plugin System: JSON-RPC + MCP

## Prerequisites

- Rust 1.75+ with `cargo`
- Node.js 20+ (for Monaco frontend)
- Tauri CLI: `cargo install tauri-cli`
- Slint compiler: `cargo install slint-build`

---

## Sprint 1: Foundation

**Goal**: Set up Tauri + Slint shell with basic window management
**Demo/Validation**:
- App launches without errors
- Window renders with dark theme
- Title bar with window controls functional

### Task 1.1: Initialize Tauri Project

- **Location**: `codnia/` root
- **Description**: Create new Tauri 2.x project with proper configuration
- **Commands**:
  ```bash
  cargo create tauri-app codnia --template slint
  cd codnia
  cargo tauri init --app-name "Codnia" --window-title "Codnia" --dev-url "http://localhost:3000"
  ```
- **Acceptance Criteria**:
  - Tauri builds successfully
  - Window appears on run
- **Validation**: `cargo tauri dev` shows empty window

### Task 1.2: Configure Slint UI Structure

- **Location**: `codnia/src/ui/`
- **Description**: Create base Slint components for window chrome
- **Files**:
  - `window.slint` - Main window container
  - `title_bar.slint` - Custom title bar with menu
  - `status_bar.slint` - Bottom status bar
- **Acceptance Criteria**:
  - Title bar renders with Codnia logo
  - Menu items (File, Edit, View, Terminal, Help) visible
  - Window controls (minimize, maximize, close) functional
- **Validation**: Visual check of rendered components

### Task 1.3: Set Up Logging & Error Handling

- **Location**: `codnia/src/main.rs`
- **Description**: Configure logging with `tracing` crate and global error handler
- **Acceptance Criteria**:
  - Logs written to `~/.codnia/logs/`
  - Panic errors caught and logged
  - Startup sequence logged
- **Validation**: Check log file after launch

### Task 1.4: Define Theme & Design Tokens

- **Location**: `codnia/src/ui/theme/`
- **Description**: Create Slint theme with color palette and typography
- **Files**:
  - `colors.slint` - Color definitions
  - `typography.slint` - Font definitions
  - `spacing.slint` - Spacing constants
- **Acceptance Criteria**:
  - All colors match SPEC.md palette
  - Typography consistent
- **Validation**: Compare with mockup

---

## Sprint 2: Core UI Layout

**Goal**: Implement sidebar, activity bar, and panel system
**Demo/Validation**:
- Sidebar icons clickable
- Activity bar shows/hides correctly
- Resizable panels work

### Task 2.1: Sidebar Icon Navigation

- **Location**: `codnia/src/ui/components/`
- **Description**: Create sidebar with icon buttons
- **Icons**: Explorer, Search, Git (Pro), Tasks (Pro), Extensions, Settings
- **Acceptance Criteria**:
  - 6 sidebar icons rendered
  - Click changes active state
  - Hover effect visible
- **Validation**: Click each icon, verify visual feedback

### Task 2.2: Activity Bar Panels

- **Location**: `codnia/src/ui/activity/`
- **Description**: Create panel containers for each activity view
- **Panels**: Explorer, Search, Git (Pro), Tasks (Pro)
- **Acceptance Criteria**:
  - Panel displays when icon clicked
  - Only one panel visible at time
- **Validation**: Switch between views

### Task 2.3: Split Pane Manager

- **Location**: `codnia/src/ui/layout/`
- **Description**: Implement resizable split panes
- **Features**:
  - Vertical split (editor | preview)
  - Horizontal split (editor above terminal)
  - Draggable dividers (4px handles)
  - Minimum pane size (200px)
- **Acceptance Criteria**:
  - Dividers draggable
  - Panes resize smoothly
  - No overlap or gap
- **Validation**: Resize all dividers, test edge cases

### Task 2.4: Panel Resize State Persistence

- **Location**: `codnia/src/core/config.rs`
- **Description**: Save and restore panel sizes
- **Acceptance Criteria**:
  - Panel sizes saved on change
  - Sizes restored on restart
- **Validation**: Resize panels, restart app, verify sizes

---

## Sprint 3: Monaco Integration

**Goal**: Embed Monaco editor in WebView with file operations
**Demo/Validation**:
- Monaco loads in editor area
- File content displays correctly
- Can edit and save files

### Task 3.1: Monaco Frontend Setup

- **Location**: `codnia/frontend/`
- **Description**: Set up Monaco with TypeScript build
- **Structure**:
  ```json
  {
    "name": "codnia-editor",
    "scripts": {
      "dev": "vite",
      "build": "tsc && vite build"
    },
    "dependencies": {
      "monaco-editor": "^0.50.0"
    }
  }
  ```
- **Files**:
  - `index.html` - Monaco container
  - `src/editor.ts` - Monaco initialization
  - `src/ipc.ts` - Tauri IPC communication
- **Acceptance Criteria**:
  - Monaco renders in dev server
  - Syntax highlighting works
  - No console errors

### Task 3.2: Tauri WebView Configuration

- **Location**: `codnia/src/main.rs`
- **Description**: Configure WebView to load Monaco frontend
- **Configuration**:
  ```rust
  WebViewBuilder::new()
      .url("http://localhost:3000")
      .devtools(true)
  ```
- **Acceptance Criteria**:
  - Monaco loads in Tauri window
  - DevTools accessible for debugging
- **Validation**: Inspect Monaco in devtools

### Task 3.3: File Operations IPC

- **Location**: `codnia/src/commands/file.rs`
- **Description**: Implement Tauri commands for file CRUD
- **Commands**:
  ```rust
  #[tauri::command]
  fn read_file(path: String) -> Result<String, String>

  #[tauri::command]
  fn write_file(path: String, content: String) -> Result<(), String>

  #[tauri::command]
  fn list_directory(path: String) -> Result<Vec<FileEntry>, String>
  ```
- **Acceptance Criteria**:
  - Can open any text file
  - Can save edits
  - Can browse directories
- **Validation**: Open, edit, save file test

### Task 3.4: Monaco-Rust Communication

- **Location**: `codnia/frontend/src/ipc.ts`
- **Description**: Bridge Monaco events to Rust backend
- **Events**:
  - `file.open` → Rust `read_file` → Monaco content
  - `file.save` → Rust `write_file`
  - `cursor.change` → Rust updates status bar
- **Acceptance Criteria**:
  - File open triggers backend read
  - Save triggers backend write
  - Cursor position updates UI
- **Validation**: Open file, edit, save, verify content

### Task 3.5: Editor Tab Integration

- **Location**: `codnia/src/ui/tabs.rs`
- **Description**: Connect Monaco to Slint tab system
- **Features**:
  - Open file creates new tab
  - Tab shows file name and modified indicator
  - Close tab saves pending changes
- **Acceptance Criteria**:
  - Each open file is a tab
  - Modified files show dot
  - Close prompts for unsaved
- **Validation**: Open multiple files, verify tabs

---

## Sprint 4: File Explorer

**Goal**: Tree view with file operations and watching
**Demo/Validation**:
- Directory tree renders correctly
- Can expand/collapse folders
- File changes detected via watch

### Task 4.1: Directory Tree Component

- **Location**: `codnia/src/ui/explorer/`
- **Description**: Create recursive tree view in Slint
- **Data Model**:
  ```rust
  struct TreeNode {
      name: String,
      path: PathBuf,
      is_directory: bool,
      children: Vec<TreeNode>,
      is_expanded: bool,
  }
  ```
- **Acceptance Criteria**:
  - Root folder displays
  - Subfolders expandable
  - Files show with icons
- **Validation**: Open large directory, verify performance

### Task 4.2: File Icons

- **Location**: `codnia/src/ui/icons.rs`
- **Description**: Map file extensions to icons
- **Icons**: TypeScript, Rust, JSON, Markdown, HTML, CSS, etc.
- **Acceptance Criteria**:
  - Known extensions show correct icon
  - Unknown extensions show generic icon
- **Validation**: Visual check of various file types

### Task 4.3: File System Watch

- **Location**: `codnia/src/core/watcher.rs`
- **Description**: Use `notify` crate to watch file changes
- **Events**: create, modify, delete, rename
- **Acceptance Criteria**:
  - New files appear in tree
  - Modified files refresh
  - Deleted files removed from tree
- **Validation**: External file changes reflected

### Task 4.4: Context Menu

- **Location**: `codnia/src/ui/context_menu.rs`
- **Description**: Right-click menu for file operations
- **Actions**: New File, New Folder, Rename, Delete, Copy Path
- **Acceptance Criteria**:
  - Menu appears on right-click
  - Actions execute correctly
  - Menu closes on click outside
- **Validation**: Test all menu actions

---

## Sprint 5: Terminal PTY

**Goal**: Native terminal emulator with PTY support
**Demo/Validation**:
- Terminal opens in bottom panel
- Can run commands (ls, cd, git)
- Input/output works correctly

### Task 5.1: PTY Setup

- **Location**: `codnia/src/core/terminal.rs`
- **Description**: Create PTY using `portable-pty` crate
- **Implementation**:
  ```rust
  let pair = portable_pty::native_pty();
  let master = pair.master;
  let slave = pair.slave;
  let child = Command::new(&shell).arg("-c").spawn(&slave)?;
  ```
- **Acceptance Criteria**:
  - PTY created successfully
  - Shell spawns (zsh/bash)
  - Process runs independently
- **Validation**: Terminal responds to commands

### Task 5.2: Terminal UI Component

- **Location**: `codnia/src/ui/terminal_panel.rs`
- **Description**: Create terminal display component
- **Features**:
  - ANSI color support
  - Scrollback buffer (10k lines)
  - Click to copy
- **Acceptance Criteria**:
  - Output renders with colors
  - Scroll works
  - Can select text
- **Validation**: Run `ls -la`, git commands, verify output

### Task 5.3: Input/Output Streaming

- **Location**: `codnia/src/core/terminal.rs`
- **Description**: Stream PTY output to UI, input to PTY
- **Implementation**: Tokio channels for async streaming
- **Acceptance Criteria**:
  - Keystrokes sent to PTY
  - PTY output displays in real-time
  - No input lag
- **Validation**: Run interactive commands (top, htop)

### Task 5.4: Multiple Terminals

- **Location**: `codnia/src/core/terminal_manager.rs`
- **Description**: Support multiple terminal instances
- **Features**:
  - New terminal button
  - Terminal tabs
  - Close terminal
- **Acceptance Criteria**:
  - Can open 3+ terminals
  - Each independent
  - Close removes terminal
- **Validation**: Open many terminals, verify no leaks

---

## Sprint 6: Search

**Goal**: File content and name search using ripgrep
**Demo/Validation**:
- Can search file names
- Can search file contents
- Results display with preview

### Task 6.1: File Name Search

- **Location**: `codnia/src/core/search.rs`
- **Description**: Fuzzy file name search with `walkdir`
- **Features**:
  - Case insensitive
  - Fuzzy matching
  - Instant results
- **Acceptance Criteria**:
  - Typing shows matches
  - Results update as you type
  - Click opens file
- **Validation**: Search for partial filename

### Task 6.2: Content Search (ripgrep)

- **Location**: `codnia/src/core/search.rs`
- **Description**: Full-text search using ripgrep
- **Features**:
  - Regex support
  - File type filter
  - Case sensitive toggle
  - Whole word toggle
- **Acceptance Criteria**:
  - Search returns matches
  - Shows line number and preview
  - Click jumps to line
- **Validation**: Search for variable/function name

### Task 6.3: Search UI

- **Location**: `codnia/src/ui/search_panel.rs`
- **Description**: Search interface with results tree
- **Features**:
  - Input with options
  - Results list with scroll
  - Match highlighting
  - Replace in files
- **Acceptance Criteria**:
  - UI displays correctly
  - Results render as list
  - Can navigate results
- **Validation**: Run searches, verify UI

### Task 6.4: Search Result Clicks

- **Location**: `codnia/src/commands/search.rs`
- **Description**: Open file at search result location
- **Acceptance Criteria**:
  - Click result opens file
  - Cursor jumps to line
  - Match highlighted
- **Validation**: Click result, verify cursor position

---

## Sprint 7: Preview Panel

**Goal**: HTML/MD preview rendering
**Demo/Validation**:
- MD renders with styling
- HTML shows in iframe
- Preview toggles on/off

### Task 7.1: Markdown Renderer

- **Location**: `codnia/src/core/preview.rs`
- **Description**: Use `pulldown-cmark` for MD rendering
- **Features**:
  - GitHub Flavored Markdown
  - Syntax highlighting in code blocks
  - Image support
- **Acceptance Criteria**:
  - MD renders correctly
  - Code blocks highlighted
  - Links work
- **Validation**: Open README.md, verify rendering

### Task 7.2: HTML Preview

- **Location**: `codnia/src/ui/preview_panel.rs`
- **Description**: iframe-based HTML preview
- **Features**:
  - Sandboxed iframe
  - File URL loading
  - Reload on change
- **Acceptance Criteria**:
  - HTML displays correctly
  - CSS renders
  - JavaScript runs (if permitted)
- **Validation**: Open HTML file, verify display

### Task 7.3: Preview Toggle

- **Location**: `codnia/src/ui/layout.rs`
- **Description**: Show/hide preview panel
- **Features**:
  - Toggle via View menu
  - Keyboard shortcut (Cmd/Ctrl + Shift + P)
  - State persistence
- **Acceptance Criteria**:
  - Preview shows/hides
  - Editor expands when hidden
  - Toggle works from menu
- **Validation**: Toggle, verify panel visibility

---

## Sprint 8: Plugin System

**Goal**: JSON-RPC based plugin host with MCP support
**Demo/Validation**:
- Can load plugin manifest
- Plugin commands appear in UI
- Plugins can be enabled/disabled

### Task 8.1: Plugin Manifest

- **Location**: `codnia/src/plugins/manifest.rs`
- **Description**: Parse plugin.toml manifests
- **Schema**:
  ```toml
  [plugin]
  name = "example"
  version = "1.0.0"

  [[commands]]
  name = "example.greet"
  handler = "greet"
  ```
- **Acceptance Criteria**:
  - Valid manifest parses
  - Invalid manifest shows error
  - Permissions extracted
- **Validation**: Test valid and invalid manifests

### Task 8.2: JSON-RPC Server

- **Location**: `codnia/src/plugins/host.rs`
- **Description**: Implement JSON-RPC 2.0 server for plugins
- **Implementation**: `jsonrpc-core` crate
- **Methods**: `plugin.list`, `plugin.enable`, `plugin.disable`
- **Acceptance Criteria**:
  - Server starts on launch
  - Can list installed plugins
  - Enable/disable works
- **Validation**: Call methods via JSON-RPC client

### Task 8.3: Plugin Lifecycle

- **Location**: `codnia/src/plugins/lifecycle.rs`
- **Description**: Manage plugin install/activate/deactivate/uninstall
- **States**: Discovered, Installed, Active, Error
- **Acceptance Criteria**:
  - Plugins load on startup
  - Can activate/deactivate
  - Errors handled gracefully
- **Validation**: Install and uninstall plugin

### Task 8.4: Plugin Commands Registry

- **Location**: `codnia/src/plugins/commands.rs`
- **Description**: Register plugin commands in command palette
- **Features**:
  - Commands appear in palette
  - Can execute plugin commands
  - Results returned to plugin
- **Acceptance Criteria**:
  - Commands visible in palette
  - Execution returns result
  - Errors displayed
- **Validation**: Execute plugin command, verify result

### Task 8.5: MCP Protocol

- **Location**: `codnia/src/plugins/mcp.rs`
- **Description**: Implement Model Context Protocol for AI tools
- **Capabilities**: resources, tools, prompts
- **Acceptance Criteria**:
  - MCP endpoints respond
  - Tools accessible
  - Resources available
- **Validation**: Test MCP client connection

---

## Sprint 9: Settings & Config

**Goal**: User settings persistence and UI
**Demo/Validation**:
- Settings panel opens
- Can change preferences
- Settings persist after restart

### Task 9.1: Config Storage

- **Location**: `codnia/src/core/config.rs`
- **Description**: Store config in `~/.codnia/config.toml`
- **Schema**: See SPEC.md Section 6.2
- **Acceptance Criteria**:
  - Config file created on first run
  - Default values set
  - Changes saved
- **Validation**: Change setting, restart, verify

### Task 9.2: Settings UI

- **Location**: `codnia/src/ui/settings.rs`
- **Description**: Settings panel with categories
- **Categories**: General, Editor, Terminal, Plugins, Pro
- **Acceptance Criteria**:
  - Settings display correctly
  - Can toggle options
  - Changes apply immediately
- **Validation**: Modify settings, verify effect

### Task 9.3: Theme Settings

- **Location**: `codnia/src/ui/theme.rs`
- **Description**: Theme selection and customization
- **Features**: Dark/Light mode, font size, font family
- **Acceptance Criteria**:
  - Can switch themes
  - Theme applies immediately
  - Preference saved
- **Validation**: Switch theme, verify change

---

## Sprint 10: Pro Features - Git

**Goal**: Git integration (commit, diff, status, branch)
**Demo/Validation**:
- Can stage and commit files
- Can view diffs
- Branch visualization works

### Task 10.1: Git2 Integration

- **Location**: `codnia-pro/src/git.rs`
- **Description**: Implement GitProvider using git2 crate
- **Methods**: status, stage, commit, diff, log, branches
- **Acceptance Criteria**:
  - Can read git status
  - Can stage files
  - Can commit
- **Validation**: Test on real git repo

### Task 10.2: Git Status Panel

- **Location**: `codnia-pro/src/ui/git_status.rs`
- **Description**: Show staged/unstaged changes
- **Features**:
  - File list with icons
  - Staged/Unstaged sections
  - Click to stage/unstage
- **Acceptance Criteria**:
  - Status shows correctly
  - Can stage individual files
  - Can stage all
- **Validation**: Check status on repo with changes

### Task 10.3: Diff View

- **Location**: `codnia-pro/src/ui/diff_view.rs`
- **Description**: Side-by-side diff display
- **Features**:
  - Added lines (green)
  - Removed lines (red)
  - Line numbers
  - Navigation
- **Acceptance Criteria**:
  - Diff displays correctly
  - Colors match convention
  - Can navigate changes
- **Validation**: View diff on modified file

### Task 10.4: Commit Interface

- **Location**: `codnia-pro/src/ui/commit_dialog.rs`
- **Description**: Commit message input and commit
- **Features**:
  - Staged files list
  - Message input
  - Commit button
  - Amend option
- **Acceptance Criteria**:
  - Can write commit message
  - Commit creates history entry
  - Author info correct
- **Validation**: Make commit, verify in git log

### Task 10.5: Branch Panel

- **Location**: `codnia-pro/src/ui/branch_panel.rs`
- **Description**: Branch list and switch
- **Features**:
  - Current branch indicator
  - Branch list
  - Create branch
  - Switch branch
- **Acceptance Criteria**:
  - Shows all branches
  - Can create new branch
  - Can switch branches
- **Validation**: Create and switch branches

---

## Sprint 11: Pro Features - Tasks & API Client

**Goal**: Task manager and REST client
**Demo/Validation**:
- Can create and manage tasks
- Can send HTTP requests

### Task 11.1: Task Data Model

- **Location**: `codnia-pro/src/tasks/model.rs`
- **Description**: Define Task struct and storage
- **Fields**: id, title, description, status, due_date, priority
- **Storage**: JSON file in project `.codnia/` directory

### Task 11.2: Task UI

- **Location**: `codnia-pro/src/ui/task_panel.rs`
- **Description**: Task list and editor
- **Features**:
  - Task list view
  - Create task
  - Edit task
  - Mark complete
  - Filter by status
- **Acceptance Criteria**:
  - Can CRUD tasks
  - Status updates persist
  - List scrolls

### Task 11.3: API Client Data Model

- **Location**: `codnia-pro/src/api/model.rs`
- **Description**: Request/Response structures
- **Features**:
  - HTTP method, URL, headers, body
  - Environment variables
  - Collections

### Task 11.4: API Client UI

- **Location**: `codnia-pro/src/ui/api_panel.rs`
- **Description**: HTTP request builder and response viewer
- **Features**:
  - Method/URL input
  - Headers editor
  - Body editor
  - Response viewer with status
- **Acceptance Criteria**:
  - Can send requests
  - Response displays
  - Can save to collection

### Task 11.5: Import/Export

- **Location**: `codnia-pro/src/api/import.rs`
- **Description**: Import from Postman/Insomnia
- **Format**: OpenAPI, Postman collection v2.1
- **Acceptance Criteria**:
  - Can import Postman collection
  - Can import Insomnia export
  - Requests map correctly

---

## Sprint 12: Pro Features - Cloud Sync

**Goal**: Settings and extension sync with E2E encryption
**Demo/Validation**:
- Settings sync across devices
- Team workspace sharing works

### Task 12.1: Sync Protocol

- **Location**: `codnia-pro/src/cloud/sync.rs`
- **Description**: Define sync protocol and encryption
- **Features**:
  - AES-256-GCM encryption
  - Delta sync (only changes)
  - Conflict resolution (last-write-wins)
- **Acceptance Criteria**:
  - Data encrypted at rest
  - Sync only transfers changes
  - Conflicts handled

### Task 12.2: User Auth

- **Location**: `codnia-pro/src/cloud/auth.rs`
- **Description**: Simple auth (email/password or OAuth)
- **Features**:
  - Login/logout
  - Session management
  - Token refresh
- **Acceptance Criteria**:
  - Can authenticate
  - Session persists
  - Logout works

### Task 12.3: Settings Sync

- **Location**: `codnia-pro/src/cloud/settings.rs`
- **Description**: Sync user settings across devices
- **Items**: Theme, keybindings, extensions, recent files
- **Acceptance Criteria**:
  - Changes sync within 30s
  - Settings apply on new device
  - Offline changes queue

### Task 12.4: Team Workspaces

- **Location**: `codnia-pro/src/cloud/teams.rs`
- **Description**: Share projects with team (up to 5)
- **Features**:
  - Invite via email
  - Role-based access (owner, member)
  - Shared project list
- **Acceptance Criteria**:
  - Can invite member
  - Member sees shared project
  - Owner can remove member

---

## Sprint 13: Marketplace

**Goal**: Plugin marketplace with publishing
**Demo/Validation**:
- Can browse plugins
- Can install/uninstall
- Can publish plugin

### Task 13.1: Marketplace API

- **Location**: `codnia-marketplace/` (separate service)
- **Description**: REST API for plugin registry
- **Endpoints**:
  - `GET /plugins` - List plugins
  - `GET /plugins/:id` - Plugin details
  - `POST /plugins` - Publish plugin
  - `GET /plugins/:id/download` - Download plugin
- **Acceptance Criteria**: API responds correctly

### Task 13.2: Marketplace UI

- **Location**: `codnia/src/ui/marketplace.rs`
- **Description**: Browse and search plugins
- **Features**:
  - Plugin cards with icons
  - Search bar
  - Category filters
  - Install button
- **Acceptance Criteria**:
  - Plugins display
  - Search works
  - Install triggers download

### Task 13.3: Plugin Publishing

- **Location**: `codnia-marketplace/publisher/`
- **Description**: Developer portal for publishing
- **Features**:
  - Upload plugin package
  - Add description/screenshots
  - Set pricing (free or paid)
  - Version management
- **Acceptance Criteria**:
  - Can publish new plugin
  - Updates work
  - Pricing updates work

### Task 13.4: Revenue Settlement

- **Location**: `codnia-marketplace/billing.rs`
- **Description**: Payment processing and settlements
- **Features**:
  - Stripe integration
  - 70/30 revenue split
  - Payout to developers
- **Acceptance Criteria**:
  - Payments process
  - Split calculated correctly
  - Payouts trigger

---

## Sprint 14: Polish & Release

**Goal**: Bug fixes, performance optimization, release
**Demo/Validation**:
- App starts < 500ms
- Binary size < 15MB
- No major bugs

### Task 14.1: Performance Optimization

- **Description**: Profile and optimize startup time
- **Targets**:
  - Cold start: < 500ms
  - File open: < 50ms
  - Memory usage: < 100MB idle
- **Validation**: Measure with perf tools

### Task 14.2: Binary Size Reduction

- **Description**: Minimize release binary
- **Techniques**:
  - LTO (Link Time Optimization)
  - codegen-units = 1
  - strip debug symbols
- **Acceptance Criteria**: Binary < 15MB

### Task 14.3: Bug Fixes

- **Description**: Fix known issues from testing
- **Process**: Triage and fix by priority
- **Validation**: No critical bugs

### Task 14.4: Release Artifacts

- **Description**: Build and sign release binaries
- **Platforms**: macOS (Intel + Apple Silicon), Windows, Linux
- **Signing**: Code signing for macOS/Windows
- **Acceptance Criteria**: All platforms build successfully

### Task 14.5: Documentation

- **Description**: Write README, setup guide, contributing guide
- **Files**:
  - README.md
  - CONTRIBUTING.md
  - docs/
- **Acceptance Criteria**: Docs complete and accurate

---

## Testing Strategy

### Unit Tests
- Rust: `cargo test` for backend modules
- TypeScript: `npm test` for Monaco frontend

### Integration Tests
- Tauri commands with actual file system
- Plugin system with sample plugin

### UI Tests
- Slint visual regression tests (future)

### Manual Testing Checklist
- [ ] App launches on macOS, Windows, Linux
- [ ] Can open project folder
- [ ] Can open, edit, save files
- [ ] Terminal works
- [ ] Search works
- [ ] Preview works
- [ ] Settings persist
- [ ] Pro features activate correctly

---

## Potential Risks & Gotchas

### 1. Monaco WebView Security
- **Risk**: WebView may block local file access
- **Mitigation**: Use `asset://` protocol or serve via local HTTP server

### 2. Slint Performance
- **Risk**: Slint may lag with many components
- **Mitigation**: Use `lazy` component loading, virtualized lists

### 3. Tauri IPC Latency
- **Risk**: High-frequency IPC (like cursor movement) may lag
- **Mitigation**: Batch events, use async channels

### 4. Plugin Isolation
- **Risk**: Plugin crashes may freeze IDE
- **Mitigation**: Run plugins in subprocess, implement timeout

### 5. Git2 Complexity
- **Risk**: Git2 has complex API, may miss edge cases
- **Mitigation**: Start with simple commands, add complexity incrementally

---

## Rollback Plan

If any sprint fails catastrophically:

1. **Revert to last working commit** - `git revert` or reset
2. **Simplify problematic module** - Strip to minimum viable
3. **Switch to simpler alternative** - E.g., if Slint fails, use egui temporarily
4. **Defer feature** - Move to future version if blocking

---

## File Structure (Final)

```
codnia/
├── src/
│   ├── main.rs
│   ├── lib.rs
│   ├── commands/
│   │   ├── mod.rs
│   │   ├── file.rs
│   │   ├── search.rs
│   │   └── terminal.rs
│   ├── ui/
│   │   ├── mod.rs
│   │   ├── window.slint
│   │   ├── components/
│   │   ├── explorer/
│   │   ├── terminal/
│   │   ├── search/
│   │   └── settings/
│   ├── core/
│   │   ├── mod.rs
│   │   ├── workspace.rs
│   │   ├── watcher.rs
│   │   ├── config.rs
│   │   └── theme.rs
│   └── plugins/
│       ├── mod.rs
│       ├── host.rs
│       ├── manifest.rs
│       └── mcp.rs
├── frontend/
│   ├── index.html
│   ├── src/
│   │   ├── editor.ts
│   │   └── ipc.ts
│   └── package.json
├── codnia-pro/ (private)
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs
│       ├── git.rs
│       ├── tasks.rs
│       ├── api.rs
│       └── cloud.rs
├── SPEC.md
├── README.md
└── Cargo.toml

codnia-marketplace/ (separate repo)
├── server/
├── web/
└── billing/
```

---

**End of Plan**