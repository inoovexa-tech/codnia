use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PluginManifest {
    pub plugin: PluginInfo,
    pub permissions: HashMap<String, bool>,
    pub commands: Vec<PluginCommand>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PluginInfo {
    pub name: String,
    pub version: String,
    pub author: String,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PluginCommand {
    pub name: String,
    pub handler: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Plugin {
    pub manifest: PluginManifest,
    pub path: PathBuf,
    pub is_active: bool,
}

impl PluginManifest {
    pub fn from_file(path: &PathBuf) -> Result<Self, String> {
        let content = std::fs::read_to_string(path).map_err(|e| e.to_string())?;
        Self::from_toml(&content)
    }

    pub fn from_toml(content: &str) -> Result<Self, String> {
        toml::from_str(content).map_err(|e| e.to_string())
    }
}

impl Plugin {
    pub fn new(manifest: PluginManifest, path: PathBuf) -> Self {
        Self {
            manifest,
            path,
            is_active: false,
        }
    }

    pub fn activate(&mut self) {
        self.is_active = true;
    }

    pub fn deactivate(&mut self) {
        self.is_active = false;
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PluginContext {
    pub workspace_id: String,
    pub editor_id: String,
    pub terminal_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PluginRequest {
    pub plugin_id: String,
    pub command: String,
    pub args: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PluginResponse {
    pub success: bool,
    pub result: Option<serde_json::Value>,
    pub error: Option<String>,
}