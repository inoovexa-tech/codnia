#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod core;

use crate::core::file_system::{DirectoryListing, FileSystem};
use crate::core::marketplace::{Marketplace, MarketplacePlugin, MarketplaceCategory};
use crate::core::plugins::PluginResponse;
use crate::core::preview::{Preview, PreviewResult, PreviewType};
use crate::core::search::Searcher;
use crate::core::search::SearchResult;
use crate::core::settings::{AppSettings, Settings};
use crate::core::terminal::TerminalInstance;
use crate::core::workspace::{Project, WorkspaceRoot, WorkspaceState};
use crate::core::AppState;
use std::panic;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use tauri::Manager;
use tauri::Emitter;
use tauri::menu::{MenuBuilder, SubmenuBuilder, MenuItemBuilder};
use tracing::{error, info, Level};
use tracing_appender::rolling::{RollingFileAppender, Rotation};
use tracing_subscriber::FmtSubscriber;
use uuid::Uuid;

fn setup_logging() {
    let log_dir = dirs::data_local_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("codnia")
        .join("logs");

    std::fs::create_dir_all(&log_dir).ok();

    let file_appender = RollingFileAppender::new(Rotation::DAILY, log_dir, "codnia.log");
    let (non_blocking, _guard) = tracing_appender::non_blocking(file_appender);

    let subscriber = FmtSubscriber::builder()
        .with_max_level(Level::INFO)
        .with_writer(non_blocking)
        .with_ansi(false)
        .finish();

    tracing::subscriber::set_global_default(subscriber).ok();

    Box::leak(Box::new(_guard));
}

fn setup_panic_handler() {
    panic::set_hook(Box::new(|panic_info| {
        let msg = if let Some(s) = panic_info.payload().downcast_ref::<&str>() {
            s.to_string()
        } else if let Some(s) = panic_info.payload().downcast_ref::<String>() {
            s.clone()
        } else {
            "Unknown panic".to_string()
        };

        let location = if let Some(loc) = panic_info.location() {
            format!("{}:{}:{}", loc.file(), loc.line(), loc.column())
        } else {
            "unknown location".to_string()
        };

        error!("PANIC at {}: {}", location, msg);
    }));
}

#[tauri::command]
fn open_settings_window(app: tauri::AppHandle<tauri::Wry>) -> Result<(), String> {
    if let Some(window) = app.get_webview_window("settings") {
        let _ = window.set_focus();
        return Ok(());
    }

    tauri::WebviewWindowBuilder::new(&app, "settings", tauri::WebviewUrl::App("settings.html".into()))
        .title("Codnia - Settings")
        .inner_size(900.0, 680.0)
        .min_inner_size(700.0, 540.0)
        .center()
        .build()
        .map_err(|e| e.to_string())?;

    Ok(())
}

#[tauri::command]
async fn add_project(
    path: String,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<Project, String> {
    let path = PathBuf::from(&path);
    let app_state = state.lock().unwrap();
    let mut manager = app_state.workspace_manager.lock().unwrap();
    manager.add_project(path)
}

#[tauri::command]
async fn remove_project(
    id: String,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<(), String> {
    let uuid = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    let app_state = state.lock().unwrap();
    let mut manager = app_state.workspace_manager.lock().unwrap();
    manager.remove_project(uuid);
    Ok(())
}

#[tauri::command]
async fn rename_project(
    id: String,
    new_name: String,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<Project, String> {
    let uuid = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    let app_state = state.lock().unwrap();
    let mut manager = app_state.workspace_manager.lock().unwrap();
    manager.rename_project(uuid, new_name)
}

#[tauri::command]
async fn get_projects(
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<Vec<Project>, String> {
    let app_state = state.lock().unwrap();
    let manager = app_state.workspace_manager.lock().unwrap();
    Ok(manager.get_all_projects().into_iter().cloned().collect())
}

#[tauri::command]
async fn set_active_project(
    id: String,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<(), String> {
    let uuid = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    let app_state = state.lock().unwrap();
    let mut manager = app_state.workspace_manager.lock().unwrap();
    manager.set_active_project(uuid)
}

#[tauri::command]
async fn get_active_workspace(
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<Option<WorkspaceState>, String> {
    let app_state = state.lock().unwrap();
    let manager = app_state.workspace_manager.lock().unwrap();
    Ok(manager.get_active_workspace().cloned())
}

#[tauri::command]
async fn get_recent_projects(
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<Vec<String>, String> {
    let app_state = state.lock().unwrap();
    let manager = app_state.workspace_manager.lock().unwrap();
    Ok(manager
        .get_recent_projects()
        .iter()
        .map(|p| p.to_string_lossy().to_string())
        .collect())
}

#[tauri::command]
async fn list_directory(
    path: String,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<DirectoryListing, String> {
    let app_state = state.lock().unwrap();
    let fs = app_state.file_system.lock().unwrap();
    fs.list_directory(&PathBuf::from(path))
}

#[tauri::command]
async fn read_file(path: String) -> Result<String, String> {
    let fs = FileSystem::new();
    fs.read_file(&PathBuf::from(path))
}

#[tauri::command]
async fn write_file(path: String, content: String) -> Result<(), String> {
    let fs = FileSystem::new();
    fs.write_file(&PathBuf::from(path), content)
}

#[tauri::command]
async fn search_files(
    root: String,
    query: String,
    max_results: usize,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<Vec<String>, String> {
    let app_state = state.lock().unwrap();
    let fs = app_state.file_system.lock().unwrap();
    let results = fs.search_files(&PathBuf::from(root), &query, max_results);
    Ok(results
        .into_iter()
        .map(|p| p.to_string_lossy().to_string())
        .collect())
}

#[tauri::command]
async fn search_content(
    root: String,
    query: String,
    max_results: usize,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<Vec<(String, String)>, String> {
    let app_state = state.lock().unwrap();
    let fs = app_state.file_system.lock().unwrap();
    let results = fs.search_content(&PathBuf::from(root), &query, max_results);
    Ok(results
        .into_iter()
        .map(|(p, l)| (p.to_string_lossy().to_string(), l))
        .collect())
}

#[tauri::command]
async fn create_file(path: String) -> Result<(), String> {
    let fs = FileSystem::new();
    fs.create_file(&PathBuf::from(path))
}

#[tauri::command]
async fn create_directory(path: String) -> Result<(), String> {
    let fs = FileSystem::new();
    fs.create_directory(&PathBuf::from(path))
}

#[tauri::command]
async fn delete_path(path: String) -> Result<(), String> {
    let fs = FileSystem::new();
    fs.delete(&PathBuf::from(path))
}

#[tauri::command]
async fn rename_path(old_path: String, new_path: String) -> Result<(), String> {
    let fs = FileSystem::new();
    fs.rename(&PathBuf::from(old_path), &PathBuf::from(new_path))
}

#[tauri::command]
async fn copy_path(src: String, dst: String) -> Result<(), String> {
    let fs = FileSystem::new();
    let src_path = PathBuf::from(&src);
    if src_path.is_dir() {
        fs.copy_dir(&src_path, &PathBuf::from(dst))
    } else {
        fs.copy_file(&src_path, &PathBuf::from(dst))
    }
}

#[tauri::command]
async fn duplicate_path(path: String) -> Result<String, String> {
    let fs = FileSystem::new();
    let new_path = fs.duplicate(&PathBuf::from(path))?;
    Ok(new_path.to_string_lossy().to_string())
}

#[tauri::command]
async fn open_in_explorer(path: String) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .arg(&path)
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(target_os = "windows")]
    {
        std::process::Command::new("explorer")
            .arg(&path)
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(target_os = "linux")]
    {
        std::process::Command::new("xdg-open")
            .arg(&path)
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[tauri::command]
async fn create_terminal(
    cwd: Option<String>,
    shell: Option<String>,
    command: Option<String>,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
    app: tauri::AppHandle<tauri::Wry>,
) -> Result<TerminalInstance, String> {
    let terminal_manager = state.lock().unwrap().terminal_manager.clone();
    let (instance, reader) = {
        let mut terminal_manager = terminal_manager.lock().unwrap();
        terminal_manager.create_instance(cwd, shell, command)?
    };

    let terminal_id_str = instance.id.to_string();
    let event_data = format!("terminal:{}:data", terminal_id_str);
    let event_exit = format!("terminal:{}:exit", terminal_id_str);
    let app_handle = app.clone();
    std::thread::spawn(move || {
        let mut reader = reader.lock().unwrap();
        let mut buffer = vec![0u8; 65536];
        loop {
            match reader.read(&mut buffer) {
                Ok(0) => {
                    let _ = app_handle.emit(&event_exit, ());
                    break;
                }
                Ok(n) => {
                    let data = match std::str::from_utf8(&buffer[..n]) {
                        Ok(s) => s.to_string(),
                        Err(_) => String::from_utf8_lossy(&buffer[..n]).to_string(),
                    };
                    let _ = app_handle.emit(&event_data, data);
                }
                Err(_) => {
                    let _ = app_handle.emit(&event_exit, ());
                    break;
                }
            }
        }
    });

    Ok(instance)
}

#[tauri::command]
async fn write_terminal(
    id: String,
    data: String,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<(), String> {
    let uuid = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    let terminal_manager = state.lock().unwrap().terminal_manager.clone();
    let terminal_manager = terminal_manager.lock().unwrap();
    terminal_manager.write(uuid, &data)
}

#[tauri::command]
async fn resize_terminal(
    id: String,
    rows: u16,
    cols: u16,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<(), String> {
    let uuid = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    let terminal_manager = state.lock().unwrap().terminal_manager.clone();
    let mut terminal_manager = terminal_manager.lock().unwrap();
    terminal_manager.resize(uuid, rows, cols)
}

#[tauri::command]
async fn kill_terminal(
    id: String,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<(), String> {
    let uuid = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    let terminal_manager = state.lock().unwrap().terminal_manager.clone();
    let mut terminal_manager = terminal_manager.lock().unwrap();
    terminal_manager.kill(uuid)
}

#[tauri::command]
async fn list_terminals(
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<Vec<TerminalInstance>, String> {
    let terminal_manager = state.lock().unwrap().terminal_manager.clone();
    let terminal_manager = terminal_manager.lock().unwrap();
    Ok(terminal_manager.get_all_instances())
}

#[tauri::command]
async fn search_content_advanced(
    root: String,
    query: String,
    is_regex: bool,
    case_sensitive: bool,
    max_results: Option<usize>,
) -> Result<SearchResult, String> {
    let mut searcher = Searcher::new();
    if let Some(max) = max_results {
        searcher = searcher.with_max_results(max);
    }
    Ok(searcher.search(&PathBuf::from(&root), &query, is_regex, case_sensitive))
}

#[tauri::command]
async fn search_files_advanced(
    root: String,
    query: String,
    max_results: Option<usize>,
) -> Result<Vec<String>, String> {
    let mut searcher = Searcher::new();
    if let Some(max) = max_results {
        searcher = searcher.with_max_results(max);
    }
    Ok(searcher.search_files(&PathBuf::from(&root), &query))
}

#[tauri::command]
async fn render_preview(
    content: String,
    preview_type: String,
) -> Result<PreviewResult, String> {
    let preview = Preview::new();
    let pt = match preview_type.to_lowercase().as_str() {
        "markdown" | "md" => PreviewType::Markdown,
        "html" | "htm" => PreviewType::Html,
        _ => PreviewType::Unknown,
    };
    let html = preview.render(&content, &pt);
    Ok(PreviewResult { html, preview_type: pt })
}

#[tauri::command]
async fn get_preview_type(
    path: String,
) -> Result<String, String> {
    let preview_type = Preview::get_preview_type(&PathBuf::from(path));
    let type_str = match preview_type {
        PreviewType::Markdown => "markdown",
        PreviewType::Html => "html",
        PreviewType::Unknown => "unknown",
    };
    Ok(type_str.to_string())
}

#[tauri::command]
async fn add_workspace_root(
    path: String,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<WorkspaceRoot, String> {
    let app_state = state.lock().unwrap();
    let mut manager = app_state.workspace_manager.lock().unwrap();
    manager.add_workspace_root(PathBuf::from(path))
}

#[tauri::command]
async fn remove_workspace_root(
    root_id: String,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<(), String> {
    let uuid = Uuid::parse_str(&root_id).map_err(|e| e.to_string())?;
    let app_state = state.lock().unwrap();
    let mut manager = app_state.workspace_manager.lock().unwrap();
    manager.remove_workspace_root(uuid)
}

#[tauri::command]
async fn get_workspace_roots(
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<Vec<WorkspaceRoot>, String> {
    let app_state = state.lock().unwrap();
    let manager = app_state.workspace_manager.lock().unwrap();
    Ok(manager.get_workspace_roots())
}

#[tauri::command]
async fn discover_plugins(
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<Vec<crate::core::plugins::PluginManifest>, String> {
    let app_state = state.lock().unwrap();
    let mut plugin_host = app_state.plugin_host.lock().unwrap();
    let config_dir = dirs::config_local_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("codnia")
        .join("plugins");
    plugin_host.discover_plugins(&config_dir)
}

#[tauri::command]
async fn activate_plugin(
    plugin_id: String,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<(), String> {
    let app_state = state.lock().unwrap();
    let mut plugin_host = app_state.plugin_host.lock().unwrap();
    plugin_host.activate_plugin(&plugin_id)
}

#[tauri::command]
async fn deactivate_plugin(
    plugin_id: String,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<(), String> {
    let app_state = state.lock().unwrap();
    let mut plugin_host = app_state.plugin_host.lock().unwrap();
    plugin_host.deactivate_plugin(&plugin_id)
}

#[tauri::command]
async fn execute_plugin_command(
    plugin_id: String,
    command: String,
    args: serde_json::Value,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<PluginResponse, String> {
    let app_state = state.lock().unwrap();
    let plugin_host = app_state.plugin_host.lock().unwrap();
    Ok(plugin_host.execute_command(&plugin_id, &command, args))
}

#[tauri::command]
async fn get_plugins(
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<Vec<crate::core::plugins::Plugin>, String> {
    let app_state = state.lock().unwrap();
    let plugin_host = app_state.plugin_host.lock().unwrap();
    Ok(plugin_host.get_all_plugins())
}

#[tauri::command]
fn get_marketplace_plugins() -> Vec<MarketplacePlugin> {
    Marketplace::get_featured_plugins()
}

#[tauri::command]
fn get_marketplace_categories() -> Vec<MarketplaceCategory> {
    Marketplace::get_categories()
}

#[tauri::command]
fn search_marketplace(query: String) -> Vec<MarketplacePlugin> {
    Marketplace::search_plugins(query)
}

#[tauri::command]
fn get_plugins_by_category(category: String) -> Vec<MarketplacePlugin> {
    Marketplace::get_plugins_by_category(category)
}

#[tauri::command]
fn install_marketplace_plugin(plugin_id: String) -> Result<String, String> {
    Marketplace::install_plugin(plugin_id)
}

#[tauri::command]
fn uninstall_marketplace_plugin(plugin_id: String) -> Result<String, String> {
    Marketplace::uninstall_plugin(plugin_id)
}

#[tauri::command]
fn publish_plugin(name: String, version: String, author: String, description: String) -> Result<String, String> {
    Marketplace::publish_plugin(name, version, author, description)
}

#[tauri::command]
fn get_settings() -> Result<AppSettings, String> {
    Settings::load()
}

#[tauri::command]
fn get_git_branch(path: String) -> Result<String, String> {
    let output = std::process::Command::new("git")
        .args(["rev-parse", "--abbrev-ref", "HEAD"])
        .current_dir(&path)
        .output()
        .map_err(|e| format!("Failed to run git: {}", e))?;

    if !output.status.success() {
        return Ok(String::new());
    }

    let branch = String::from_utf8_lossy(&output.stdout).trim().to_string();
    Ok(branch)
}

#[tauri::command]
fn save_settings(settings: AppSettings) -> Result<(), String> {
    Settings::save(&settings)
}

#[tauri::command]
fn get_keyboard_shortcuts() -> Result<std::collections::HashMap<String, String>, String> {
    let shortcuts = Settings::get_shortcuts()?;
    Ok(shortcuts.shortcuts)
}

#[tauri::command]
fn update_keyboard_shortcut(action: String, shortcut: String) -> Result<(), String> {
    Settings::update_shortcut(action, shortcut)
}

fn main() {
    setup_logging();
    setup_panic_handler();

    info!("Codnia IDE starting up...");
    info!("Version: {}", env!("CARGO_PKG_VERSION"));

    let app_state = Arc::new(Mutex::new(AppState::new()));

    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .manage(app_state)
        .invoke_handler(tauri::generate_handler![
            open_settings_window,
            add_project,
            remove_project,
            rename_project,
            get_projects,
            set_active_project,
            get_active_workspace,
            get_recent_projects,
            list_directory,
            read_file,
            write_file,
            search_files,
            search_content,
            create_file,
            create_directory,
            delete_path,
            rename_path,
            copy_path,
            duplicate_path,
            open_in_explorer,
            create_terminal,
            write_terminal,
            resize_terminal,
            kill_terminal,
            list_terminals,
            search_content_advanced,
            search_files_advanced,
            render_preview,
            get_preview_type,
            add_workspace_root,
            remove_workspace_root,
            get_workspace_roots,
            discover_plugins,
            activate_plugin,
            deactivate_plugin,
            execute_plugin_command,
            get_plugins,
            get_marketplace_plugins,
            get_marketplace_categories,
            search_marketplace,
            get_plugins_by_category,
            install_marketplace_plugin,
            uninstall_marketplace_plugin,
            publish_plugin,
            get_settings,
            save_settings,
            get_keyboard_shortcuts,
            update_keyboard_shortcut,
            get_git_branch
        ])
        .setup(|app| {
            info!("Tauri app setup complete");

            let menu = MenuBuilder::new(app)
                .item(&SubmenuBuilder::new(app, "File")
                    .item(&MenuItemBuilder::with_id("new_file", "New File").accelerator("CmdOrCtrl+N").build(app)?)
                    .item(&MenuItemBuilder::with_id("open_file", "Open File...").accelerator("CmdOrCtrl+O").build(app)?)
                    .separator()
                    .item(&MenuItemBuilder::with_id("save", "Save").accelerator("CmdOrCtrl+S").build(app)?)
                    .item(&MenuItemBuilder::with_id("save_as", "Save As...").accelerator("CmdOrCtrl+Shift+S").build(app)?)
                    .separator()
                    .item(&MenuItemBuilder::with_id("close_tab", "Close Tab").accelerator("CmdOrCtrl+W").build(app)?)
                    .build()?)
                .item(&SubmenuBuilder::new(app, "Edit")
                    .item(&MenuItemBuilder::with_id("undo", "Undo").accelerator("CmdOrCtrl+Z").build(app)?)
                    .item(&MenuItemBuilder::with_id("redo", "Redo").accelerator("CmdOrCtrl+Shift+Z").build(app)?)
                    .separator()
                    .item(&MenuItemBuilder::with_id("cut", "Cut").accelerator("CmdOrCtrl+X").build(app)?)
                    .item(&MenuItemBuilder::with_id("copy", "Copy").accelerator("CmdOrCtrl+C").build(app)?)
                    .item(&MenuItemBuilder::with_id("paste", "Paste").accelerator("CmdOrCtrl+V").build(app)?)
                    .item(&MenuItemBuilder::with_id("select_all", "Select All").accelerator("CmdOrCtrl+A").build(app)?)
                    .build()?)
                .item(&SubmenuBuilder::new(app, "View")
                    .item(&MenuItemBuilder::with_id("toggle_sidebar", "Toggle Sidebar").accelerator("CmdOrCtrl+B").build(app)?)
                    .item(&MenuItemBuilder::with_id("toggle_terminal", "Toggle Terminal").accelerator("CmdOrCtrl+`").build(app)?)
                    .item(&MenuItemBuilder::with_id("global_search", "Global Search").accelerator("CmdOrCtrl+Shift+F").build(app)?)
                    .build()?)
                .build()?;

            app.set_menu(menu)?;

            let handle = app.handle().clone();
            app.on_menu_event(move |_window, event| {
                let _ = handle.emit("menu-event", event.id.as_ref());
            });

            let _window = app.get_webview_window("main");
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}