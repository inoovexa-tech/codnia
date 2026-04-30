pub mod file_system;
pub mod marketplace;
pub mod persistence;
pub mod plugins;
pub mod preview;
pub mod search;
pub mod settings;
pub mod terminal;
pub mod workspace;

use file_system::FileSystem;
use plugins::PluginHost;
use preview::Preview;
use settings::{AppSettings, Settings};
use terminal::TerminalManager;
use workspace::WorkspaceManager;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

pub struct AppState {
    pub workspace_manager: Arc<Mutex<WorkspaceManager>>,
    pub file_system: Arc<Mutex<FileSystem>>,
    pub plugin_host: Arc<Mutex<PluginHost>>,
    pub terminal_manager: Arc<Mutex<TerminalManager>>,
    #[allow(dead_code)]
    pub preview: Preview,
    #[allow(dead_code)]
    pub settings: AppSettings,
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

        let settings = Settings::load().unwrap_or_default();

        Self {
            workspace_manager: Arc::new(Mutex::new(workspace_manager)),
            file_system: Arc::new(Mutex::new(FileSystem::new())),
            plugin_host: Arc::new(Mutex::new(plugin_host)),
            terminal_manager: Arc::new(Mutex::new(TerminalManager::new())),
            preview: Preview::new(),
            settings,
        }
    }
}

impl Default for AppState {
    fn default() -> Self {
        Self::new()
    }
}