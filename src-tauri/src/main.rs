#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod core;

use crate::core::file_system::{DirectoryListing, FileSystem};
use crate::core::plugins::PluginResponse;
use crate::core::preview::{Preview, PreviewResult, PreviewType};
use crate::core::search::Searcher;
use crate::core::search::SearchResult;
use crate::core::terminal::TerminalInstance;
use crate::core::workspace::{Project, WorkspaceRoot, WorkspaceState};
use crate::core::AppState;
use std::panic;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use tauri::Manager;
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
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<TerminalInstance, String> {
    let app_state = state.lock().unwrap();
    let mut terminal_manager = app_state.terminal_manager.lock().unwrap();
    terminal_manager.create_instance(cwd, shell)
}

#[tauri::command]
async fn write_terminal(
    id: String,
    data: String,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<(), String> {
    let uuid = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    let app_state = state.lock().unwrap();
    let mut terminal_manager = app_state.terminal_manager.lock().unwrap();
    terminal_manager.write(uuid, &data)
}

#[tauri::command]
async fn read_terminal(
    id: String,
    timeout_ms: Option<u64>,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<String, String> {
    let uuid = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    let app_state = state.lock().unwrap();
    let terminal_manager = app_state.terminal_manager.lock().unwrap();
    terminal_manager.read(uuid, timeout_ms.unwrap_or(10))
}

#[tauri::command]
async fn resize_terminal(
    id: String,
    rows: u16,
    cols: u16,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<(), String> {
    let uuid = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    let app_state = state.lock().unwrap();
    let mut terminal_manager = app_state.terminal_manager.lock().unwrap();
    terminal_manager.resize(uuid, rows, cols)
}

#[tauri::command]
async fn kill_terminal(
    id: String,
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<(), String> {
    let uuid = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    let app_state = state.lock().unwrap();
    let mut terminal_manager = app_state.terminal_manager.lock().unwrap();
    terminal_manager.kill(uuid)
}

#[tauri::command]
async fn list_terminals(
    state: tauri::State<'_, Arc<Mutex<AppState>>>,
) -> Result<Vec<TerminalInstance>, String> {
    let app_state = state.lock().unwrap();
    let terminal_manager = app_state.terminal_manager.lock().unwrap();
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
    Ok(searcher.search(&PathBuf::from(root), &query, is_regex, case_sensitive))
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
    Ok(searcher
        .search_files(&PathBuf::from(root), &query)
        .into_iter()
        .map(|p| p.to_string_lossy().to_string())
        .collect())
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
            add_project,
            remove_project,
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
            open_in_explorer,
            create_terminal,
            write_terminal,
            read_terminal,
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
            get_plugins
        ])
        .setup(|app| {
            info!("Tauri app setup complete");
            let _window = app.get_webview_window("main");
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}