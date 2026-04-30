use crate::core::plugins::manifest::{Plugin, PluginCommand, PluginContext, PluginManifest, PluginRequest, PluginResponse};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use uuid::Uuid;

pub struct PluginHost {
    plugins: HashMap<String, Plugin>,
    active_plugin_id: Option<String>,
}

impl PluginHost {
    pub fn new() -> Self {
        Self {
            plugins: HashMap::new(),
            active_plugin_id: None,
        }
    }

    pub fn discover_plugins(&mut self, plugins_dir: &PathBuf) -> Result<Vec<PluginManifest>, String> {
        let mut manifests = Vec::new();

        if !plugins_dir.exists() {
            std::fs::create_dir_all(plugins_dir).map_err(|e| e.to_string())?;
            return Ok(manifests);
        }

        for entry in std::fs::read_dir(plugins_dir).map_err(|e| e.to_string())? {
            let entry = entry.map_err(|e| e.to_string())?;
            let path = entry.path();

            if path.is_dir() {
                let manifest_path = path.join("plugin.toml");
                if manifest_path.exists() {
                    match PluginManifest::from_file(&manifest_path) {
                        Ok(manifest) => {
                            let plugin = Plugin::new(manifest.clone(), path);
                            let plugin_id = manifest.plugin.name.clone();
                            self.plugins.insert(plugin_id.clone(), plugin);
                            manifests.push(manifest);
                        }
                        Err(e) => {
                            tracing::warn!("Failed to load plugin manifest at {:?}: {}", manifest_path, e);
                        }
                    }
                }
            }
        }

        Ok(manifests)
    }

    pub fn activate_plugin(&mut self, plugin_id: &str) -> Result<(), String> {
        if let Some(plugin) = self.plugins.get_mut(plugin_id) {
            plugin.activate();
            self.active_plugin_id = Some(plugin_id.to_string());
            Ok(())
        } else {
            Err(format!("Plugin not found: {}", plugin_id))
        }
    }

    pub fn deactivate_plugin(&mut self, plugin_id: &str) -> Result<(), String> {
        if let Some(plugin) = self.plugins.get_mut(plugin_id) {
            plugin.deactivate();
            if self.active_plugin_id.as_deref() == Some(plugin_id) {
                self.active_plugin_id = None;
            }
            Ok(())
        } else {
            Err(format!("Plugin not found: {}", plugin_id))
        }
    }

    pub fn execute_command(&self, plugin_id: &str, command: &str, args: serde_json::Value) -> PluginResponse {
        if let Some(plugin) = self.plugins.get(plugin_id) {
            if !plugin.is_active {
                return PluginResponse {
                    success: false,
                    result: None,
                    error: Some(format!("Plugin {} is not active", plugin_id)),
                };
            }

            let cmd_found = plugin.manifest.commands.iter().any(|c| c.name == command);
            if !cmd_found {
                return PluginResponse {
                    success: false,
                    result: None,
                    error: Some(format!("Command {} not found in plugin {}", command, plugin_id)),
                };
            }

            PluginResponse {
                success: true,
                result: Some(serde_json::json!({
                    "executed": command,
                    "plugin": plugin_id,
                    "args": args
                })),
                error: None,
            }
        } else {
            PluginResponse {
                success: false,
                result: None,
                error: Some(format!("Plugin not found: {}", plugin_id)),
            }
        }
    }

    pub fn get_plugin(&self, plugin_id: &str) -> Option<&Plugin> {
        self.plugins.get(plugin_id)
    }

    pub fn get_all_plugins(&self) -> Vec<Plugin> {
        self.plugins.values().cloned().collect()
    }

    pub fn get_active_plugins(&self) -> Vec<Plugin> {
        self.plugins.values().filter(|p| p.is_active).cloned().collect()
    }

    pub fn uninstall_plugin(&mut self, plugin_id: &str) -> Result<(), String> {
        if let Some(mut plugin) = self.plugins.remove(plugin_id) {
            plugin.deactivate();
            if plugin.path.exists() && plugin.path.is_dir() {
                std::fs::remove_dir_all(&plugin.path).map_err(|e| e.to_string())?;
            }
            Ok(())
        } else {
            Err(format!("Plugin not found: {}", plugin_id))
        }
    }

    pub fn install_plugin(&mut self, source_path: &PathBuf, dest_dir: &PathBuf) -> Result<PluginManifest, String> {
        if !source_path.exists() {
            return Err(format!("Source plugin path does not exist: {}", source_path.display()));
        }

        let manifest_path = source_path.join("plugin.toml");
        if !manifest_path.exists() {
            return Err("No plugin.toml found in source directory".to_string());
        }

        let manifest = PluginManifest::from_file(&manifest_path)?;
        let plugin_id = manifest.plugin.name.clone();
        let dest_path = dest_dir.join(&plugin_id);

        if dest_path.exists() {
            return Err(format!("Plugin {} is already installed", plugin_id));
        }

        std::fs::copy(source_path, &dest_path).map_err(|e| e.to_string())?;

        let plugin = Plugin::new(manifest.clone(), dest_path);
        self.plugins.insert(plugin_id, plugin);

        Ok(manifest)
    }
}

impl Default for PluginHost {
    fn default() -> Self {
        Self::new()
    }
}