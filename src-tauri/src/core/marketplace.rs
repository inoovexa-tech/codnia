use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MarketplacePlugin {
    pub id: String,
    pub name: String,
    pub version: String,
    pub author: String,
    pub description: String,
    pub downloads: u64,
    pub rating: f32,
    pub categories: Vec<String>,
    pub icon_url: Option<String>,
    pub repo_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MarketplaceCategory {
    pub id: String,
    pub name: String,
    pub icon: String,
    pub count: u32,
}

pub struct Marketplace;

impl Marketplace {
    #[allow(dead_code)]
    fn get_marketplace_dir() -> PathBuf {
        dirs::config_local_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("codnia")
            .join("marketplace")
    }

    #[allow(dead_code)]
    fn get_cache_path() -> PathBuf {
        Self::get_marketplace_dir().join("cache.json")
    }

    pub fn get_featured_plugins() -> Vec<MarketplacePlugin> {
        vec![
            MarketplacePlugin {
                id: "opencode-assistant".to_string(),
                name: "OpenCode Assistant".to_string(),
                version: "1.0.0".to_string(),
                author: "Codnia Team".to_string(),
                description: "AI-powered code completion and refactoring suggestions using OpenCode".to_string(),
                downloads: 15420,
                rating: 4.8,
                categories: vec!["ai".to_string(), "productivity".to_string()],
                icon_url: None,
                repo_url: Some("https://github.com/codnia/opencode-assistant".to_string()),
            },
            MarketplacePlugin {
                id: "gitLens".to_string(),
                name: "GitLens".to_string(),
                version: "0.2.0".to_string(),
                author: "Eric Lane".to_string(),
                description: "Supercharge Git in Codnia with rich annotations and visualizations".to_string(),
                downloads: 28300,
                rating: 4.6,
                categories: vec!["git".to_string(), "productivity".to_string()],
                icon_url: None,
                repo_url: Some("https://github.com/codnia/gitlens".to_string()),
            },
            MarketplacePlugin {
                id: "prettier".to_string(),
                name: "Prettier Formatter".to_string(),
                version: "2.0.0".to_string(),
                author: "Prettier Team".to_string(),
                description: "Code formatter supporting JavaScript, TypeScript, JSON, CSS and more".to_string(),
                downloads: 41200,
                rating: 4.7,
                categories: vec!["formatter".to_string(), "productivity".to_string()],
                icon_url: None,
                repo_url: Some("https://github.com/codnia/prettier".to_string()),
            },
            MarketplacePlugin {
                id: "docker".to_string(),
                name: "Docker Tools".to_string(),
                version: "1.5.0".to_string(),
                author: "Docker Inc".to_string(),
                description: "Manage containers, images, volumes and compose files directly from Codnia".to_string(),
                downloads: 18700,
                rating: 4.5,
                categories: vec!["devops".to_string(), "containers".to_string()],
                icon_url: None,
                repo_url: Some("https://github.com/codnia/docker-tools".to_string()),
            },
            MarketplacePlugin {
                id: "remote-ssh".to_string(),
                name: "Remote SSH".to_string(),
                version: "0.3.0".to_string(),
                author: "Codnia Team".to_string(),
                description: "Open folders on remote machines via SSH and work on them as local files".to_string(),
                downloads: 22100,
                rating: 4.4,
                categories: vec!["remote".to_string(), "ssh".to_string()],
                icon_url: None,
                repo_url: Some("https://github.com/codnia/remote-ssh".to_string()),
            },
        ]
    }

    pub fn get_categories() -> Vec<MarketplaceCategory> {
        vec![
            MarketplaceCategory {
                id: "ai".to_string(),
                name: "AI & Assistant".to_string(),
                icon: "🤖".to_string(),
                count: 12,
            },
            MarketplaceCategory {
                id: "git".to_string(),
                name: "Git & Version Control".to_string(),
                icon: "🔀".to_string(),
                count: 8,
            },
            MarketplaceCategory {
                id: "formatter".to_string(),
                name: "Formatters & Linters".to_string(),
                icon: "✨".to_string(),
                count: 15,
            },
            MarketplaceCategory {
                id: "devops".to_string(),
                name: "DevOps & Cloud".to_string(),
                icon: "☁️".to_string(),
                count: 10,
            },
            MarketplaceCategory {
                id: "productivity".to_string(),
                name: "Productivity".to_string(),
                icon: "⚡".to_string(),
                count: 24,
            },
            MarketplaceCategory {
                id: "themes".to_string(),
                name: "Themes".to_string(),
                icon: "🎨".to_string(),
                count: 32,
            },
        ]
    }

    pub fn search_plugins(query: String) -> Vec<MarketplacePlugin> {
        let query_lower = query.to_lowercase();
        Self::get_featured_plugins()
            .into_iter()
            .filter(|p| {
                p.name.to_lowercase().contains(&query_lower)
                    || p.description.to_lowercase().contains(&query_lower)
                    || p.categories.iter().any(|c| c.to_lowercase().contains(&query_lower))
            })
            .collect()
    }

    pub fn get_plugins_by_category(category: String) -> Vec<MarketplacePlugin> {
        Self::get_featured_plugins()
            .into_iter()
            .filter(|p| p.categories.contains(&category))
            .collect()
    }

    pub fn install_plugin(plugin_id: String) -> Result<String, String> {
        let plugins_dir = dirs::config_local_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("codnia")
            .join("plugins");

        std::fs::create_dir_all(&plugins_dir).map_err(|e| e.to_string())?;

        let plugin_path = plugins_dir.join(format!("{}.toml", plugin_id));
        if plugin_path.exists() {
            return Err(format!("Plugin {} is already installed", plugin_id));
        }

        let template = format!(
            r#"[plugin]
name = "{}"
version = "1.0.0"
author = "Marketplace"
description = "Installed from marketplace"

[permissions]
file.read = true
file.write = false

[[commands]]
name = "{}.greet"
handler = "greet"
"#,
            plugin_id, plugin_id
        );

        std::fs::write(&plugin_path, template).map_err(|e| e.to_string())?;

        Ok(format!("Plugin {} installed successfully", plugin_id))
    }

    pub fn uninstall_plugin(plugin_id: String) -> Result<String, String> {
        let plugin_path = dirs::config_local_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("codnia")
            .join("plugins")
            .join(format!("{}.toml", plugin_id));

        if !plugin_path.exists() {
            return Err(format!("Plugin {} is not installed", plugin_id));
        }

        std::fs::remove_file(&plugin_path).map_err(|e| e.to_string())?;

        Ok(format!("Plugin {} uninstalled successfully", plugin_id))
    }

    pub fn publish_plugin(name: String, version: String, author: String, description: String) -> Result<String, String> {
        if name.is_empty() || version.is_empty() || author.is_empty() {
            return Err("Name, version and author are required".to_string());
        }

        let published_dir = dirs::config_local_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("codnia")
            .join("published");

        std::fs::create_dir_all(&published_dir).map_err(|e| e.to_string())?;

        let manifest_path = published_dir.join(format!("{}.toml", name.replace(" ", "-").to_lowercase()));

        let manifest = format!(
            r#"[plugin]
name = "{}"
version = "{}"
author = "{}"
description = "{}"
published_at = "{}"

[permissions]
file.read = true
file.write = true

[[commands]]
"#,
            name,
            version,
            author,
            description,
            chrono_now()
        );

        std::fs::write(&manifest_path, manifest).map_err(|e| e.to_string())?;

        Ok(format!("Plugin {} published successfully", name))
    }
}

fn chrono_now() -> String {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();
    format!("{}", now)
}