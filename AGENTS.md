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

Release workflow
When the user asks to release a new version, follow this exact sequence:

1. **Determine the new version number** using semver (`MAJOR.MINOR.PATCH`):
   - **Patch** (`0.0.x`): bug fixes, minor tweaks, no new features.
   - **Minor** (`0.x.0`): new features, non-breaking changes.
   - **Major** (`x.0.0`): breaking changes.
   - Read the current version from `src-tauri/Cargo.toml` (`version` field) and `src-tauri/tauri.conf.json` (`version` field). They must match. Increment based on the type of changes since the last release.

2. **Update version in all config files** (they must stay in sync):
   - `src-tauri/Cargo.toml` → `version = "..."`
   - `src-tauri/tauri.conf.json` → `"version": "..."`

3. **Update `CHANGELOG.md`** — add a new section at the top:
   ```markdown
   ## [x.y.z] — YYYY-MM-DD
   ### Added / Fixed / Changed
   - bullet per change
   ```

4. **Build** — run the full production build to verify everything compiles:
   ```bash
   cd frontend && npm run build
   cd src-tauri && cargo build --release
   ```
   If the build fails, stop and fix errors before continuing.

5. **Commit** — stage all changes and commit with message:
   ```
   release: vX.Y.Z — concise description
   ```

6. **Create git tag** and push:
   ```bash
   git tag -a "vX.Y.Z" -m "Release vX.Y.Z"
   git push origin main --follow-tags
   ```

7. **Create GitHub release** with the `gh` CLI:
   ```bash
   gh release create "vX.Y.Z" --title "vX.Y.Z" --notes "$(cat CHANGELOG.md | sed -n '/^## \[X.Y.Z\]/,/^## \[/p' | head -n -1)"
   ```
   Attach the built artifacts from `src-tauri/target/release/bundle/` (macOS: `.dmg`, `.app`).

8. **Verify** — open the GitHub release page and confirm everything looks correct.

**Important**: Never skip the build step. Never commit without running `npm run build` first.

Constraints
- Tauri desktop app only; there is no separate web deployment target.
- Frontend dependencies are in `frontend/package.json`; the repo has no top-level `package.json` or monorepo tooling.
