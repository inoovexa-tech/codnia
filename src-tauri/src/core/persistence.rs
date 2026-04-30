use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct AppConfig {
    pub recent_projects: Vec<RecentProject>,
    pub last_active_project_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecentProject {
    pub path: String,
    pub name: String,
    pub last_opened: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct WorkspaceStore {
    pub projects: Vec<StoredProject>,
    pub open_tabs: Vec<StoredTab>,
    pub expanded_folders: Vec<String>,
    pub recent_projects: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoredProject {
    pub id: String,
    pub name: String,
    pub path: String,
    pub is_active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoredTab {
    pub id: String,
    pub path: String,
    pub name: String,
    pub is_modified: bool,
    pub scroll_position: Option<(u32, u32)>,
    pub cursor_position: Option<(u32, u32)>,
}

pub struct Persistence;

impl Persistence {
    fn get_config_dir() -> Result<PathBuf, String> {
        let dir = dirs::config_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("codnia");
        
        if !dir.exists() {
            fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
        }
        
        Ok(dir)
    }

    fn get_config_path() -> Result<PathBuf, String> {
        Ok(Self::get_config_dir()?.join("config.json"))
    }

    fn get_workspace_path() -> Result<PathBuf, String> {
        Ok(Self::get_config_dir()?.join("workspace.json"))
    }

    pub fn load_config() -> Result<AppConfig, String> {
        let path = Self::get_config_path()?;
        if !path.exists() {
            return Ok(AppConfig::default());
        }
        let content = fs::read_to_string(&path).map_err(|e| e.to_string())?;
        serde_json::from_str(&content).map_err(|e| e.to_string())
    }

    pub fn save_config(config: &AppConfig) -> Result<(), String> {
        let path = Self::get_config_path()?;
        let content = serde_json::to_string_pretty(config).map_err(|e| e.to_string())?;
        fs::write(&path, content).map_err(|e| e.to_string())
    }

    pub fn load_workspace() -> Result<WorkspaceStore, String> {
        let path = Self::get_workspace_path()?;
        if !path.exists() {
            return Ok(WorkspaceStore::default());
        }
        let content = fs::read_to_string(&path).map_err(|e| e.to_string())?;
        serde_json::from_str(&content).map_err(|e| e.to_string())
    }

    pub fn save_workspace(workspace: &WorkspaceStore) -> Result<(), String> {
        let path = Self::get_workspace_path()?;
        let content = serde_json::to_string_pretty(workspace).map_err(|e| e.to_string())?;
        fs::write(&path, content).map_err(|e| e.to_string())
    }

    pub fn get_recent_projects(limit: usize) -> Result<Vec<RecentProject>, String> {
        let config = Self::load_config()?;
        Ok(config.recent_projects.into_iter().take(limit).collect())
    }

    pub fn add_recent_project(path: String, name: String) -> Result<(), String> {
        let mut config = Self::load_config()?;
        
        config.recent_projects.retain(|p| p.path != path);
        
        let recent = RecentProject {
            path,
            name,
            last_opened: chrono_now(),
        };
        config.recent_projects.insert(0, recent);
        
        if config.recent_projects.len() > 10 {
            config.recent_projects.truncate(10);
        }
        
        Self::save_config(&config)
    }

    pub fn remove_recent_project(path: &str) -> Result<(), String> {
        let mut config = Self::load_config()?;
        config.recent_projects.retain(|p| p.path != path);
        Self::save_config(&config)
    }
}

fn chrono_now() -> String {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();
    format!("{}", now)
}