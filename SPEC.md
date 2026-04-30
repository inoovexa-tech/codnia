# Codnia - Technical Specification

**Version:** 0.1.0
**Last Updated:** 2026-04-30

---

## 1. Overview

### 1.1 What is Codnia?

Codnia is an agent-first IDE designed for the new era of AI-assisted development. Built from the ground up with Rust and a modern architecture, it provides a lightning-fast, extensible development environment with a focus on developer productivity and seamless AI agent integration.

### 1.2 Core Principles

- **Performance First:** Every component optimized for speed and low resource consumption
- **Simplicity:** Clean, intuitive UI without unnecessary complexity
- **Extensibility:** Plugin system with MCP (Model Context Protocol) for AI tool integration
- **Agent-First:** Architecture designed for AI agents to work alongside developers

---

## 2. Architecture

### 2.1 Technology Stack

| Layer | Technology | Version |
|-------|------------|---------|
| Desktop Shell | Tauri | 2.x |
| UI Framework | Slint | 1.x |
| Code Editor | Monaco | Latest |
| Backend Language | Rust | 1.75+ |
| Frontend (Monaco) | TypeScript | 5.x |

### 2.2 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Tauri Window Manager                        │
│                    (Multi-Window Support)                        │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────┼───────────────────────────────────┐
│                    SLINT UI LAYER (100% Rust)                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  Window Chrome    │  Activity Bar  │  Status Bar            ││
│  │  - Title Bar      │  - Explorer    │  - Git Branch          ││
│  │  - Menu Bar       │  - Search      │  - Problems Count      ││
│  │  - Window Ctrls   │  - Extensions  │  - Cursor Position     ││
│  │                   │  - Settings    │  - Encoding           ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  Editor Area                                               ││
│  │  ┌───────────────┬───────────────┬─────────────────────┐    ││
│  │  │ Tab Bar       │ Split Panes   │ Preview Panel       │    ││
│  │  │ - File Tabs   │ - Resizable   │ - HTML Preview      │    ││
│  │  │ - Closeable   │ - Draggable   │ - Markdown Render   │    ││
│  │  │ - Active      │ - Vertical    │                     │    ││
│  │  └───────────────┴───────────────┴─────────────────────┘    ││
│  │  ┌─────────────────────────────────────────────────────┐    ││
│  │  │         Monaco Editor (WebView - JS)               │    ││
│  │  │         - Syntax Highlighting                       │    ││
│  │  │         - IntelliSense                             │    ││
│  │  │         - Multi-cursor                              │    ││
│  │  └─────────────────────────────────────────────────────┘    ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  Bottom Panel                                              ││
│  │  ┌─────────────┬─────────────┬─────────────┬─────────────┐    ││
│  │  │ Terminal   │ Problems    │ Output     │ Tasks (PRO) │    ││
│  │  │ PTY Native │             │            │            │    ││
│  │  └─────────────┴─────────────┴─────────────┴─────────────┘    ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────┼───────────────────────────────────┐
│                    RUST BACKEND (Tauri)                        │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Core Modules (Community)                                   │ │
│  │ ├─ FileSystem (notify crate)                              │ │
│  │ ├─ WorkspaceManager (multi-root)                          │ │
│  │ ├─ Terminal (portable-pty)                                │ │
│  │ ├─ Search (ripgrep integration)                           │ │
│  │ ├─ Preview (pulldown-cmark, iframe)                        │ │
│  │ ├─ PluginHost (JSON-RPC server)                           │ │
│  │ └─ WindowManager                                          │ │
│  ├────────────────────────────────────────────────────────────┤ │
│  │ Pro Modules (Private Plugin)                               │ │
│  │ ├─ GitProvider (git2)                                      │ │
│  │ ├─ TaskProvider                                           │ │
│  │ ├─ ApiClient (reqwest)                                    │ │
│  │ └─ CloudSync                                              │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 Data Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   User     │────▶│  Slint UI   │────▶│   Tauri     │
│  Input     │     │  (Rust)    │     │  Commands   │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                              │
                    ┌─────────────────────────┼─────────────────────────┐
                    ▼                         ▼                         ▼
              ┌───────────┐            ┌───────────┐            ┌───────────┐
              │  File     │            │  Terminal │            │  Plugin   │
              │  System   │            │  PTY      │            │  Host     │
              └───────────┘            └───────────┘            └───────────┘
```

---

## 3. Module Specifications

### 3.1 Window Manager

**Responsibility:** Create, manage, and coordinate multiple windows.

**Features:**
- Main window (editor workspace)
- Settings window
- Plugin marketplace window
- Pro activation window

**Tauri APIs:**
- `tauri::window::Builder` for window creation
- `WindowEvent` for window state management
- Inter-window communication via Tauri events

### 3.2 Workspace Manager

**Responsibility:** Manage multiple project directories simultaneously.

**Data Model:**
```rust
pub struct Workspace {
    pub id: Uuid,
    pub name: String,
    pub path: PathBuf,
    pub is_active: bool,
    pub files: HashMap<PathBuf, FileState>,
}

pub struct ProjectState {
    pub workspace_id: Uuid,
    pub open_files: Vec<PathBuf>,
    pub active_file: Option<PathBuf>,
    pub expanded_folders: Vec<PathBuf>,
}
```

**Features:**
- Open folder as project
- Multiple projects in tabs
- File watching (notify crate)
- Recent projects list

### 3.3 File Explorer

**Responsibility:** Display and navigate project file tree.

**Component Structure (Slint):**
```
TreeView
├── TreeNode (folder)
│   ├── TreeNode (file)
│   └── TreeNode (file)
└── TreeNode (file)
```

**Features:**
- Expand/collapse folders
- File icons based on extension
- Context menu (new file, rename, delete)
- Drag and drop (future)

### 3.4 Editor Tab Manager

**Responsibility:** Manage open file tabs and their state.

**Data Model:**
```rust
pub struct Tab {
    pub id: Uuid,
    pub path: PathBuf,
    pub name: String,
    pub is_active: bool,
    pub is_modified: bool,
    pub scroll_position: (u32, u32),
    pub cursor_position: (u32, u32),
}
```

**Features:**
- Open/close tabs
- Tab reordering (drag)
- Close all / close others
- Modified indicator
- Tab overflow (scroll)

### 3.5 Monaco Editor Host

**Responsibility:** Embed Monaco editor in WebView and communicate with it.

**Integration:**
```rust
// Tauri WebView configuration
WebViewBuilder::new()
    .url("http://localhost:3000/monaco")
    .devtools(true) // for debugging
```

**IPC Messages:**
```typescript
// Frontend (TypeScript)
interface MonacoMessage {
    type: 'file.open' | 'file.save' | 'cursor.move' | 'selection.change';
    payload: unknown;
}

// Rust backend
#[tauri::command]
fn execute_command(command: String, args: Vec<String>) -> Result<String, String>;
```

### 3.6 Split Pane Manager

**Responsibility:** Allow resizable split views of editor panels.

**Layout Options:**
- Horizontal split (side by side)
- Vertical split (stacked)
- Tab groups

**Implementation:**
- Slint Grid layout with splitter widgets
- Resize handles with drag detection
- Minimum pane size constraints (200px)

### 3.7 Preview Panel

**Responsibility:** Render HTML and Markdown previews.

**HTML Preview:**
- iframe element pointing to file:// URL
- Sandbox restrictions
- Reload on file change

**Markdown Preview:**
- Rust renderer using `pulldown-cmark`
- GitHub Flavored Markdown support
- Syntax highlighting for code blocks

### 3.8 Terminal

**Responsibility:** Provide native PTY terminal emulator.

**Implementation:**
- `portable-pty` crate for PTY creation
- Command spawning via `std::process::Command`
- Input/output streaming via Tauri async channels

**Features:**
- Multiple terminal instances
- Tab per terminal
- Clear/reset
- Copy/paste
- Scrollback buffer (10,000 lines)

### 3.9 Search

**Responsibility:** Search across files, directories, and content.

**Implementation:**
- File search: `walkdir` crate
- Content search: `ripgrep` integration
- Fuzzy matching for file names

**UI Components:**
- Search input with regex toggle
- File filter (glob patterns)
- Replace in files
- Results tree with preview

### 3.10 Status Bar

**Responsibility:** Display contextual information.

**Sections:**
| Section | Content |
|---------|---------|
| Git | Current branch, status |
| Problems | Error/warning count |
| Encoding | UTF-8, etc. |
| Language | File language mode |
| Position | Line, column |
| Spaces | Indentation config |

### 3.11 Plugin System (Community)

**Architecture:**
```
┌─────────────────────────────────────────────────────────┐
│                    Plugin Host (Rust)                   │
│  ┌───────────────────────────────────────────────────┐ │
│  │  JSON-RPC Server                                   │ │
│  │  - Plugin registration                             │ │
│  │  - Method invocation                               │ │
│  │  - Event dispatching                               │ │
│  └───────────────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────────────┐ │
│  │  Plugin Registry                                   │ │
│  │  - Manifest parsing                               │ │
│  │  - Dependency resolution                           │ │
│  │  - Lifecycle management                           │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────┐
│                   Plugin (Any Language)                 │
│  ┌───────────────────────────────────────────────────┐ │
│  │  Manifest (plugin.toml)                           │ │
│  │  - name, version, author                          │ │
│  │  - dependencies                                   │ │
│  │  - entry point                                    │ │
│  │  - permissions                                    │ │
│  └───────────────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────────────┐ │
│  │  Implementation                                   │ │
│  │  - JSON-RPC client                                │ │
│  │  - Custom commands                                │ │
│  │  - UI contributions                               │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Plugin Manifest:**
```toml
[plugin]
name = "my-plugin"
version = "1.0.0"
author = "Developer"
description = "A sample plugin"

[permissions]
file.read = true
file.write = false
terminal.execute = true

[[commands]]
name = "my-plugin.greet"
handler = "greet"
```

### 3.12 Marketplace (Community)

**Features:**
- Browse available plugins
- Search plugins
- Install/uninstall plugins
- Plugin ratings and reviews
- Developer dashboard

**Data Flow:**
```
User → Marketplace UI → API Gateway → Plugin Registry
                              ↓
                      Download Plugin
                              ↓
                    Plugin Host Installation
```

### 3.13 Pro Modules (Private)

#### Git Provider

**Features:**
- Commit with staging
- Diff view (staged/unstaged)
- Branch visualization
- Status overview
- History log

**Implementation:**
```rust
pub trait GitProvider {
    fn status(&self) -> Result<GitStatus>;
    fn stage(&self, paths: Vec<PathBuf>) -> Result<()>;
    fn commit(&self, message: &str) -> Result<CommitResult>;
    fn diff(&self, staged: bool) -> Result<String>;
    fn log(&self, limit: usize) -> Result<Vec<Commit>>;
    fn branches(&self) -> Result<Vec<Branch>>;
}
```

#### Task Provider

**Features:**
- Task list per project
- Create/edit/delete tasks
- Due dates and priorities
- Status tracking (todo, in progress, done)
- JQL-like filtering (PRO feature)

#### API Client

**Features:**
- HTTP methods (GET, POST, PUT, DELETE, PATCH)
- Headers and body configuration
- Environment variables
- Request history
- Import from Postman/Insomnia

#### Cloud Sync

**Features:**
- Settings sync
- Extension sync
- Recent projects sync
- Team collaboration (up to 5 members)
- End-to-end encryption

---

## 4. UI/UX Specification

### 4.1 Layout Structure

```
┌─────────────────────────────────────────────────────────────────┐
│  Title Bar (40px)                                               │
│  [Logo] [File] [Edit] [View] [Terminal] [Help]    [─] [□] [×] │
├────┬────────────────────────────────────────────────────────────┤
│ S  │ Activity Bar │ Editor Area                                │
│ I  │ (48px)       │                                            │
│ D  │              │ ┌────────────────────────────────────────┐ │
│ E  │ [Explorer]   │ │ Tab1 │ Tab2 │ Tab3 │                    │ │
│ B  │ [Search]     │ ├────────────────────────────────────────┤ │
│ A  │ [Git]        │ │                                        │ │
│ R  │ [Tasks]      │ │        Monaco Editor                   │ │
│    │ [Extensions] │ │        (WebView)                       │ │
│    │              │ │                                        │ │
│    │              │ ├────────────────────────────────────────┤ │
│    │              │ │ Preview Panel (toggleable)            │ │
│    │              │ └────────────────────────────────────────┘ │
│    │              ├────────────────────────────────────────────┤
│    │              │ Bottom Panel (Terminal / Problems / etc)  │
│    │              │ [Terminal] [Problems] [Output]    [▲]     │
├────┴──────────────┴────────────────────────────────────────────┤
│  Status Bar (24px)                                              │
│  [main ✓] [0 problems]          [Spaces: 4] [UTF-8] [TypeScript] [Ln 13, Col 4] │
└─────────────────────────────────────────────────────────────────┘

Legend:
├── Sidebar Icons: Explorer, Search, Git, Tasks, Extensions, Settings
├── Activity Bar: Context-sensitive panel (file tree, search results, etc.)
├── Editor Area: Tabs, Monaco, Preview
└── Bottom Panel: Terminal, Problems, Output, etc.
```

### 4.2 Color Palette (Dark Mode - Default)

| Token | Hex | Usage |
|-------|-----|-------|
| `bg-primary` | `#0c0c0c` | Main background |
| `bg-secondary` | `#111111` | Sidebar, panels |
| `bg-tertiary` | `#1a1a1a` | Hover states |
| `bg-hover` | `#222222` | Active hover |
| `bg-active` | `#2a2a2a` | Selected/active |
| `border` | `#2a2a2a` | Borders |
| `border-light` | `#333333` | Lighter borders |
| `text-primary` | `#ffffff` | Main text |
| `text-secondary` | `#888888` | Secondary text |
| `text-tertiary` | `#555555` | Muted text |
| `accent` | `#5a5a5a` | Subtle accents |
| `accent-blue` | `#0070f3` | Primary actions |
| `accent-green` | `#10b981` | Success states |
| `accent-red` | `#ef4444` | Errors |
| `accent-yellow` | `#f59e0b` | Warnings |

### 4.3 Typography

| Element | Font | Size | Weight |
|---------|------|------|--------|
| Title Bar | System | 14px | 600 |
| Menu Items | System | 12px | 400 |
| Activity Bar | System | 12px | 500 |
| Tab Labels | System | 13px | 400 |
| File Tree | System | 13px | 400 |
| Editor | SF Mono / Fira Code | 13px | 400 |
| Terminal | SF Mono / Fira Code | 13px | 400 |
| Status Bar | System | 12px | 400 |

### 4.4 Spacing System

| Token | Value | Usage |
|-------|-------|-------|
| `space-xs` | 4px | Tight spacing |
| `space-sm` | 8px | Small gaps |
| `space-md` | 12px | Default gaps |
| `space-lg` | 16px | Section spacing |
| `space-xl` | 24px | Large gaps |

### 4.5 Component Specifications

#### Sidebar Icons
- Size: 32x32px
- Border radius: 6px
- Icon size: 20x20px
- Gap between icons: 4px

#### Tabs
- Height: 36px (40px container)
- Padding: 0 16px
- Close button: 16x16px
- Active indicator: 2px bottom border (accent-blue)

#### Split Panes
- Minimum size: 200px
- Handle width: 4px
- Handle hover: accent color

#### Terminal
- Font: SF Mono
- Line height: 20px
- Padding: 12px 16px

---

## 5. Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+N` | Open new tab dropdown |
| `Ctrl+\`` | Open Terminal |
| `Ctrl+Shift+O` | Run OpenCode in terminal |
| `Ctrl+Shift+C` | Run Claude Code in terminal |
| `Ctrl+Shift+X` | Run Codex in terminal |

---

## 6. Plugin System Specification

### 5.1 MCP (Model Context Protocol)

Codnia uses MCP for AI agent integration, enabling standardized communication between AI tools and the IDE.

**Core Concepts:**
- **Resources:** Files, directories, git history, terminal output
- **Tools:** Execute commands, read/write files, search
- **Prompts:** Reusable prompt templates

**MCP Schema:**
```json
{
  "schema_version": "1.0",
  "capabilities": {
    "resources": ["file", "git", "terminal"],
    "tools": ["execute", "search", "index"],
    "prompts": ["code_review", "generate_tests"]
  }
}
```

### 5.2 Plugin Interface

```rust
pub trait Plugin: Any + Send + Sync {
    fn manifest(&self) -> PluginManifest;
    fn initialize(&mut self, ctx: PluginContext) -> Result<(), Error>;
    fn execute(&self, command: &str, args: Value) -> Result<Value, Error>;
    fn shutdown(&self) -> Result<(), Error>;
}

pub struct PluginContext {
    pub workspace: WorkspaceHandle,
    pub editor: EditorHandle,
    pub terminal: TerminalHandle,
    pub events: EventEmitter,
}
```

### 5.3 Plugin Lifecycle

```
1. Discovery    → Scan plugins directory
2. Validation   → Parse manifest, check permissions
3. Installation → Copy to user plugins directory
4. Activation   → Load binary, call initialize()
5. Execution    → Handle commands/events
6. Deactivation → Call shutdown(), unload
7. Uninstall    → Remove files
```

### 5.4 Built-in Commands

| Command | Description |
|---------|-------------|
| `workspace.open` | Open folder as workspace |
| `file.read` | Read file contents |
| `file.write` | Write file contents |
| `file.search` | Search in files |
| `terminal.run` | Execute command in terminal |
| `editor.get_cursor` | Get cursor position |
| `editor.set_content` | Set editor content |

---

## 6. Data Storage

### 6.1 Configuration Directory

```
~/.codnia/
├── config.toml          # User settings
├── plugins/             # Installed plugins
├── extensions/          # VS Code extensions (future)
├── workspaces.json      # Recent workspaces
└── logs/               # Application logs
```

### 6.2 Config Schema

```toml
[general]
theme = "dark"
font_size = 13
font_family = "SF Mono"

[editor]
tab_size = 2
insert_spaces = true
word_wrap = "off"
minimap = true

[terminal]
shell = "zsh"
font_size = 13

[pro]
license_key = ""
last_sync = "2024-01-01T00:00:00Z"
```

### 6.3 Workspace State

Stored per workspace in `.codnia/` directory:

```
project/.codnia/
├── state.json          # Open files, cursor positions
├── bookmarks.json      # User bookmarks
└── workspace.meta      # Workspace metadata
```

---

## 7. Performance Targets

| Metric | Target |
|--------|--------|
| Cold startup | < 500ms |
| Hot startup | < 100ms |
| File open | < 50ms |
| Search (1M files) | < 1s |
| Memory usage (idle) | < 100MB |
| Binary size | < 15MB |

---

## 8. Security

### 8.1 Sandboxing

- Plugins run in isolated subprocesses
- File system access controlled via permissions
- No arbitrary code execution

### 8.2 License Validation (Pro)

- License key verification on activation
- Periodic validation (daily)
- Graceful degradation on failure

---

## 9. Licensing & Distribution

### 9.1 Open Source (Community)

- **License:** AGPLv3
- **Repository:** github.com/codnia/codnia
- **Distribution:** Pre-built binaries, package managers

### 9.2 Commercial (Pro)

- **License:** Commercial EULA
- **Repository:** github.com/codnia/codnia-pro (private)
- **Distribution:** Separate installer with Pro features

### 9.3 Pricing

| Edition | Price | Features |
|---------|-------|----------|
| Community | Free | Core IDE, basic plugins |
| Pro | $129/year | Git, Tasks, API Client, Cloud Sync |

---

## 10. Roadmap

### Phase 1: Foundation (v0.1.0 - v0.2.0)
- [x] Tauri window setup
- [x] Sidebar and activity bar
- [x] Monaco editor integration
- [x] File explorer basic
- [x] Tab management
- [x] Terminal PTY
- [x] Project management with persistence (~/.codnia/)
- [x] New tab dropdown (+ button)
- [x] Keyboard shortcuts (Ctrl+N, Ctrl+`, Ctrl+Shift+O/C/X)
- [x] Settings panel with minimap toggle
- [x] Monaco minimap disabled by default

### Phase 2: Core Features (v0.3.0 - v0.4.0)
- [x] Multi-root workspaces
- [x] File search (ripgrep)
- [x] Preview panel (HTML/MD)
- [x] Status bar
- [x] Basic plugin system
- [x] Persistence layer (JSON config in ~/.codnia/)

### Phase 3: Ecosystem (v0.5.0 - v0.6.0)
- [ ] Marketplace UI
- [ ] Plugin publishing
- [ ] Settings UI
- [ ] Theme system
- [ ] Keyboard shortcuts

### Phase 4: Pro Features (v1.0.0)
- [ ] Git integration (pro)
- [ ] Task manager (pro)
- [ ] API client (pro)
- [ ] Cloud sync (pro)
- [ ] Pro license activation

---

## 11. Glossary

| Term | Definition |
|------|------------|
| **Activity Bar** | Left sidebar with view icons |
| **Monaco** | VS Code's editor component |
| **MCP** | Model Context Protocol for AI integration |
| **PTY** | Pseudo Terminal |
| **Slint** | Rust UI framework |
| **Tauri** | Rust desktop framework |
| **Worktree** | Git worktree representation |

---

## Appendix A: Key Dependencies

```toml
[dependencies]
tauri = { version = "2", features = ["devtools"] }
slint = "1"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["full"] }
notify = "6"
walkdir = "2"
git2 = { optional = true }
reqwest = { optional = true }
pulldown-cmark = "0.9"
portable-pty = "0.8"
ripgrep = "0.11"
uuid = { version = "1", features = ["v4"] }
```

---

## Appendix B: File Structure

```
codnia/
├── src/                      # Main Tauri application
│   ├── main.rs               # Entry point
│   ├── lib.rs                # Library root
│   ├── commands/             # Tauri commands
│   ├── ui/                  # Slint UI components
│   ├── core/                # Core modules
│   │   ├── workspace.rs     # Workspace management
│   │   ├── file_system.rs   # File operations
│   │   ├── terminal.rs      # Terminal PTY
│   │   └── search.rs        # Search functionality
│   └── plugins/             # Plugin system
│       ├── host.rs          # Plugin host
│       └── manifest.rs      # Plugin manifest
├── frontend/                # Monaco WebView (separate build)
│   ├── src/
│   └── index.html
├── codnia-pro/              # Private Pro plugin
│   ├── Cargo.toml
│   └── src/
├── SPEC.md
├── README.md
└── Cargo.toml
```

---

**End of Specification**