# Codnia — Agent Context

Repository layout
- `frontend/` — Vite + React 19 + Tailwind CSS 4 + shadcn/ui + Monaco Editor + xterm.js. **No root `package.json`.**
- `src-tauri/` — Tauri v2 Rust backend. All business logic is under `src/core/`.
- `PLAN.md`, `SPEC.md` — Design docs (not executable).

Developer commands
- `cd frontend && npm run dev` — Vite dev server, **port 3030** (`strictPort`), required by Tauri dev.
- `cd frontend && npm run build` — `tsc && vite build`. Runs automatically as Tauri `beforeBuildCommand`.
- `cd src-tauri && cargo build` / `cargo run` — Standard Rust/Tauri.
- **No test, lint, or typecheck scripts exist.** `npm run build` is the only verification step.

Frontend architecture
- Entry points: `index.html` (main IDE) and `settings.html` (settings window). Both point to separate TSX entry files.
- Path alias `@/` resolves to `./src/` via Vite + tsconfig.
- **Tailwind CSS 4** configuration is inside `src/globals.css` via `@theme` and `@import "tailwindcss"`. There is no `tailwind.config.js`.
- shadcn/ui configured as `style: "new-york"`, `rsc: false`, icon library `lucide-react`.
- `tsconfig.json`: `noUnusedLocals: true`, `noUnusedParameters: true` — build fails on unused imports/variables.

Build / bundling
- Vite `base: "./"` and `outDir: "dist"`; `emptyOutDir: true`.
- Manual chunks: `monaco`, `react`, `radix`.
- Tauri `tauri.conf.json` expects dev server at `http://localhost:3030`.

Backend (Rust) architecture
- `main.rs` registers Tauri commands and emits menu events (`menu-event`).
- `core/mod.rs` defines `AppState`, which holds `WorkspaceManager`, `FileSystem`, `PluginHost`, `TerminalManager` behind `Arc<Mutex<...>>`.
- Commands receive state via `tauri::State<'_, Arc<Mutex<AppState>>>`.

Subsystems to know
- **Terminal**: Uses `portable-pty`. Each terminal runs on a background thread and emits events named `terminal:{id}:data` and `terminal:{id}:exit`.
- **Plugins**: Discovered from `config_local_dir()/codnia/plugins`.
- **Persistence**: Workspace state and settings are persisted to disk via `core/persistence.rs`.
- **Logging**: tracing with a daily-rolling file appender to `data_local_dir()/codnia/logs/codnia.log`.
- **Settings window**: Spawned by `open_settings_window` command as a separate `WebviewWindow` pointing to `settings.html`.

Constraints
- Tauri desktop app only; there is no separate web deployment target.
- Frontend dependencies are in `frontend/package.json`; the repo has no top-level `package.json` or monorepo tooling.
