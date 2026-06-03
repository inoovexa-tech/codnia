## [0.19.0] — 2026-06-03

### Added
- Tasks: autocomplete tag suggestions when adding tags
- Editor: extended syntax highlighting to env, dockerfile, makefile, nginx, toml, ini, conf, log, properties, gitignore
- Modal: redesigned Add Project picker with Finder-style sidebar and iCloud support
- Tasks: support \n as newline in descriptions and show preview in collapsed view

### Fixed
- Tasks: reload tasks when switching tabs and manual refresh button
- Editor: gray comment color, env detection for .env.* files, real-time highlight
- Database: add row/column borders and align header/data columns
- Database: surface row delete errors in alert
- Tasks: auto-reload sidebar when tasks.json is modified externally
- Editor: enable hash comment highlighting for .env files
- Theme: force consistent gray comment color across all themes

## [0.18.0] — 2026-05-30

### Added
- Notes system with folder-based sidebar, drag & drop reorganize, sort, inline rename, preview, and persistent expand/collapse
- Enhanced tag parsing and Sendable conformance for Notes
- Horizontal scrollbar or multiselect popover for tag filters in Tasks
- REST API client enhancements: multi-header support, auth toggle, JSON formatting and syntax highlighting
- Expanded theme palette with dedicated syntax colors (syntax2, syntax3, syntax4, syntax5, syntax6, comment)

### Fixed
- Terminal scroll position preservation when switching tabs
- Theme: harmonized light theme colors, increased text opacity, fixed hardcoded white foregrounds, replaced Menu with themed popover
- Tasks: sort menu sizing and selection display, general UX improvements
- REST API client: various bug fixes and UX improvements
- Git sidebar: various bug fixes and improvements
- Notes: path resolution, error feedback, stubs, NoteDirectory id
- Editor: save and restore scroll/cursor position per tab
- Crash on NSTextView string initialization
- Pure black background restored for Codnia Dark theme

### Removed
- Editor line numbers gutter (reverted Sprint 1—3 code editor improvements)

## [0.17.0] — 2026-05-27

### Added
- Browser DevTools v2 — console improvements, Elements/Network/Storage/Sources/Application panels, docking, floating window, Chrome theme

### Fixed
- Database explorer showing wrong tables after switching databases
- In-file search highlights and next/prev navigation not working in split panes

## [0.16.2] — 2026-05-22

### Fixed
- Kill entire process group when closing terminal tab
- Remove AI tab loading/running state tracking from sidebar

## [0.16.1] — 2026-05-22

### Fixed
- MySQL quoting and silent error swallowing on database fetch
- Improve loading spinner detection for AI tabs
- Correct Sparkle framework path in DMG and appcast signature
- Resolve Swift 6 build warnings

### Added
- Replace database type SF Symbols with official brand logos
- Add Connect option to DB connection context menu
- Scroll-while-selecting in terminal via mouseDown/mouseUp swizzling

## [0.16.0] — 2026-05-21

### Added
- Browser DevTools with Console, Elements, Network, and Storage panels
- Notes sidebar organized by directory structure
- ER diagram viewer with movable cards and PNG export
- SQL auto-complete and SSH tunnel support
- MySQL and SQLite database support (PostgreSQL, MySQL, SQLite)
- Connection groups and saved queries
- DDL visual schema editing (create/alter/drop tables, columns, indexes)
- Editable database grid with staged changes and apply
- Per-tab query history with export and query cancellation
- Edit connection option in context menu
- Distinct SF Symbols for PostgreSQL, MySQL, and SQLite connections
- Persist browser tab state per worktree

### Fixed
- Resolve Swift 6 concurrency warnings in build
- Deduplicate ungrouped connections in sidebar listing
- Tree collapse after DDL operations (alter column, etc.)
- SQL query cross-contamination when switching database tabs
- Database insert error propagation and SQL escaping bugs
- Reset index creation state after successful creation
- Drop column result check and tree refresh after successful drop
- Only show project loading spinner for AI tabs (opencode, claude, codex)

## [0.15.0] — 2026-05-19

### Added
- Right-click Clear context menu on terminal
- Scope REST API collections and environments per project

### Fixed
- Terminate split pane sessions when closing terminal tab or pane
- Terminal loading indicator not showing due to onDataReceived closure override
- Make tabs fixed-width (160px) with leading icon and trailing close button
- Preserve split pane state when switching projects
- Preserve per-leaf terminal session IDs when switching back to a split tab

## [0.14.0] — 2026-05-18

### Added
- Theme system with 27 built-in themes (5-color palette) + visual selector in settings
- Sparkle auto-update framework integration
- REST API client plugin with collections, history, and context menu

### Fixed
- Replace List with ScrollView in settings to restore mouse scroll wheel
- Propagate worktree removal errors to UI alert
- Replace WindowDragView with frame-tracking TitlebarBackgroundView for native window operations
- Make task description field multi-line in expanded section

## [0.12.1] — 2026-05-18

### Fixed
- Detect worktree already removed from git when deleting
- Make split state per-tab instead of global (SwitchToTab)
- Use index as destination for tab reordering drag & drop

## [0.12.0] — 2026-05-16

### Added
- Format git changes count display with k suffix for numbers >= 1000
- Confirmation dialog before discarding git changes
- Increased tab width and title truncation with ellipsis
- Custom directory/image browser modals replacing NSOpenPanel
- HTML file preview with WKWebView
- Markdown preview toggle in sidebar

### Fixed
- Disable wantsLayer on NSHostingView to fix NSOpenPanel sheet rendering
- Disable split and hide icon for browser tabs
- Resolve directory expand/collapse in file explorer
- Prevent autosave from saving wrong content when switching tabs
- Re-enable tab drag-and-drop reordering
- Fix unstage all and individual unstage in source control sidebar

### Changed
- Remove all print debug statements

## [0.11.1] — 2026-05-15

### Fixed
- Fix new terminal tab not appearing when another terminal is already running
  - Force TerminalSingleView to recreate when active tab changes to ensure the correct terminal session is displayed

## [0.11.0] — 2026-05-15

### Added
- Editor split pane functionality
- Terminal shared session split views with improved divider dragging
- Built-in Notes plugin with scoped .codnia/notes directory
- File and task drag-and-drop to terminal
- Swift 6 concurrency warning resolution

### Changed
- Remove explorer, search, source control icons from topbar; keep only split icons and expand sidebar toggle

### Fixed
- Replace blue active pane border with light gray
- Preserve original pane scrollback/history on split, create fresh sessions for restored tabs
- Use send(txt:) instead of feed(byteArray:) for terminal paste
- Properly detect merge conflicts in git sidebar
- Handle already-deleted worktree gracefully when branch also deleted

## [0.10.3] — 2026-05-14

### Fixed
- Restore editor, query, and preview visibility while preserving terminal session state

## [0.10.2] — 2026-05-14

### Changed
- Add version release workflow documentation to README

## [0.10.1] — 2026-05-14

### Added
- Git merge branch selector dropdown with native branch list

### Fixed
- Make add-task input expand vertically for long text
- Add visible active project indicator with blue leading bar and icon overlay in sidebar
- Restore task content in drag payload broken by reorder feature

## [0.10.0] — 2026-05-14

### Added
- SQL database manager with PostgreSQL support
- Database connection management (save, edit, delete connections)
- Database explorer with schema browser (tables, views, columns, indexes, foreign keys)
- SQL query editor with syntax highlighting and execution
- Paginated data grid for query results with sorting and column resize
- Keyboard shortcut for New SQL Query
- Tab bar sidebar toggle buttons (Explorer, Search, Git, Tasks)

### Changed
- Refactored TabBarView to closure-based architecture, removing direct workspace/settings dependencies

## [0.9.0] — 2026-05-11

### Added
- Plugin-based task system with sidebar integration
- Drag-and-drop task to tab bar
- AI terminal activity detection with sidebar loading indicator
- Auto-dismiss git sidebar notifications after 5 seconds

### Fixed
- Improve task drag-drop to tab bar and terminal
- Remove Task: prefix from dropped task content
- Switch active project when clicking worktree from another project
- Set fixed height with scroll for git changes in sidebar

## [0.8.0] — 2026-05-09

### Added
- AI terminal shortcuts (Cmd+Shift+O for OpenCode, Cmd+Shift+C for Claude Code, Cmd+Shift+X for Codex)
- Keyboard shortcuts management with rebinding and recording input in settings
- SwiftTerm-based terminal integration with OpenCode/Claude Code/Codex CLI tabs and auto-command execution
- Git worktree support with sidebar UI and merge integration
- Per-file added/removed line counts in source control sidebar
- Persist worktree expansion state per project, collapse non-active by default

### Fixed
- Restore settings window opening via NSWindowController
- Reduce editor invalidation storms and eliminate redundant highlighting and git polling
- Persist sidebar toggle state and prevent redundant project reload on view appear
- Hide loading indicator during auto-refresh in sidebar

### Changed
- Replace accent colors with white for active toolbar icons, add explorer icon

## [0.7.1] — 2026-05-08

### Fixed
- Add contentShape to collapsed sidebar Add Project button

## [0.7.0] — 2026-05-08

### Added
- Collapsible commit history section in sidebar (GitService)
- Bulk discard options with file selection in git sidebar
- WindowDragArea and TopbarFreeArea components for window dragging
- Image and PDF preview in tabs
- In-file search with Cmd+F shortcut, highlight matches, and auto-scroll navigation
- Tab bar overflow dropdown menu

### Fixed
- Unstage files with spaces in path using shell
- Handle discard for untracked files by removing from filesystem
- Real-time refresh and fix refresh button state
- Tab bar height fix

## [0.6.1] — 2026-05-08

### Fixed
- Fix Add Project button freezing on DMG builds
  - Restore `NSOpenPanel.runModal()` instead of `beginSheetModal` which caused HIRunLoopSemaphore deadlock
  - Add `.contentShape(Rectangle())` for full clickable button area

## [0.6.0] — 2026-05-08

### Added
- Source Control panel in right sidebar with diff viewer
- Markdown preview toggle with full text selection
- Project switching with Cmd+Up/Down keyboard shortcuts

### Fixed
- Make add project button area fully clickable
- Close pipe write end to unblock git changes counting and prevent deadlock on stderr
- Skip runtime icon assignment in .app bundle to preserve Dock rounded corners
- Load app icon from SPM resource bundle for proper Dock display
- Restore double-click to zoom window on title bar drag area

## [0.5.1] — 2026-05-07

### Fixed
- Eliminate app hangs caused by thread starvation in GitService
  - Replace `waitUntilExit()` with `terminationHandler` + `async/await` — threads no longer block waiting for git processes
  - Run diff, staged, and untracked git commands concurrently instead of sequentially
  - Add cancellable `Task` management in `WorkspaceService` to prevent stale git requests from piling up
  - Replace `Timer`-based auto-refresh with `Task.sleep` to avoid spawning unbounded background threads

## [0.5.0] — 2026-05-07

### Added
- Syntax highlighting in code editor
- Black background theme for editor
- Tab reordering via drag-and-drop

### Fixed
- Prevent app hang on termination by stopping auto-refresh timer and file observers
- Enable smooth window drag without conflict with tab interactions

## [0.4.0] — 2026-05-07

### Added
- Project icon picker with auto-detection and custom upload

### Fixed
- Forward mouse scroll wheel to TUI apps as mouse button events
- Improve git changes count accuracy with numstat and real-time observers

## [0.3.0] — 2026-05-07

### Added
- Auto-save with 2-second debounce after typing stops
- Resizable sidebar with persisted widths (file explorer and right panel)
- Show hidden files toggle in file explorer

### Fixed
- Save editor content when switching tabs
- Disable window drag from content area, add dedicated drag area in tab bar
- Fix right sidebar resizable divider width updates

## [0.2.0] — 2026-05-06

### Added
- Rename project modal with option to rename directory
- Git changes count (+/-) displayed with green/red colors in sidebar and status bar
- Auto-refresh git changes every 3 seconds via WorkspaceService timer
- Persist editor tabs state per project (fileTabs, terminalTabs, activeTabId)
- Double-click on title bar to zoom/maximize window
- Improved terminal tab identification (type + index + directory)
- Auto-refresh file explorer and show hidden files

### Fixed
- Sidebar project row styling (active: gray bg, inactive: no bg, active icon: blue)
- AttributeGraph cycle issues resolved by using timer-based updates instead of computed properties
- Rename project now properly updates sidebar UI
- Git changes aligned to the right of branch name

## [0.1.1] — 2026-05-06

### Fixed
- Terminal sessions now persist across tab switches and project changes
- TerminalManager keeps instances alive globally, only hiding/showing based on active tab
- Fixed terminal process being killed when switching between projects
- Added TerminalContainerManager for persistent NSView container across SwiftUI recreation

### Added
- Keyboard shortcuts: Cmd+N (new file), Cmd+T (new terminal), Cmd+S (save), Cmd+Shift+S (save as), Cmd+W (close tab)
- Keyboard shortcut hints in TabBarView "+" menu

## [0.1.0] — 2026-05-06

### Added
- Initial release of Codnia IDE
- Swift/SwiftUI macOS native application
- Code editor with syntax highlighting via SwiftTerm
- File tree navigation and project management
- Tab-based editing interface
- Terminal integration
- Settings panel
- Application icon
- macOS 13 (Ventura) minimum support

### Fixed
- Terminal typing issues in release/DMG builds
- Removed duplicate terminal process creation in TerminalService
- Fixed environment variables (LANG, TERM, HOME) for LocalProcessTerminalView
- Improved first responder handling with Coordinator pattern
- Added Info.plist for proper app bundle configuration
