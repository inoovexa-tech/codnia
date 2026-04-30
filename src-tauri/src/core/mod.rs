pub mod file_system;
pub mod persistence;
pub mod plugins;
pub mod preview;
pub mod search;
pub mod terminal;
pub mod workspace;

use file_system::FileSystem;
use persistence::Persistence;
use plugins::PluginHost;
use preview::Preview;
use search::Searcher;
use terminal::{TerminalInstance, TerminalManager};
use workspace::{Project, WorkspaceManager, WorkspaceState};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

pub struct AppState {
    pub workspace_manager: Arc<Mutex<WorkspaceManager>>,
    pub file_system: Arc<Mutex<FileSystem>>,
    pub plugin_host: Arc<Mutex<PluginHost>>,
    pub terminal_manager: Arc<Mutex<TerminalManager>>,
    pub preview: Preview,
}

impl AppState {
    pub fn new() -> Self {
        let workspace_manager = WorkspaceManager::load_from_disk()
            .unwrap_or_else(|_| WorkspaceManager::new());

        let mut plugin_host = PluginHost::new();
        let config_dir = dirs::config_local_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("codnia")
            .join("plugins");
        let _ = plugin_host.discover_plugins(&config_dir);

        Self {
            workspace_manager: Arc::new(Mutex::new(workspace_manager)),
            file_system: Arc::new(Mutex::new(FileSystem::new())),
            plugin_host: Arc::new(Mutex::new(plugin_host)),
            terminal_manager: Arc::new(Mutex::new(TerminalManager::new())),
            preview: Preview::new(),
        }
    }
}

impl Default for AppState {
    fn default() -> Self {
        Self::new()
    }
}