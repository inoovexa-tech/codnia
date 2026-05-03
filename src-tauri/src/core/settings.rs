use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    pub theme: ThemeSettings,
    pub keyboard_shortcuts: KeyboardShortcuts,
    pub editor: EditorSettings,
    pub terminal: TerminalSettings,
    pub ui: UiSettings,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThemeSettings {
    pub name: String,
    pub dark_mode: bool,
    pub font_size: u32,
    pub font_family: String,
    pub color_overrides: HashMap<String, String>,
}

impl Default for ThemeSettings {
    fn default() -> Self {
        Self {
            name: "dark".to_string(),
            dark_mode: true,
            font_size: 13,
            font_family: "SF Mono".to_string(),
            color_overrides: HashMap::new(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KeyboardShortcuts {
    pub shortcuts: HashMap<String, String>,
}

impl Default for KeyboardShortcuts {
    fn default() -> Self {
        let mut shortcuts = HashMap::new();
        shortcuts.insert("ctrl+n".to_string(), "new_tab".to_string());
        shortcuts.insert("ctrl+`".to_string(), "toggle_terminal".to_string());
        shortcuts.insert("ctrl+shift+o".to_string(), "run_opencode".to_string());
        shortcuts.insert("ctrl+shift+c".to_string(), "run_claude_code".to_string());
        shortcuts.insert("ctrl+shift+x".to_string(), "run_codex".to_string());
        shortcuts.insert("ctrl+b".to_string(), "toggle_sidebar".to_string());
        shortcuts.insert("ctrl+shift+f".to_string(), "global_search".to_string());
        shortcuts.insert("ctrl+,".to_string(), "open_settings".to_string());
        Self { shortcuts }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EditorSettings {
    pub tab_size: u32,
    pub insert_spaces: bool,
    pub word_wrap: String,
    pub minimap_enabled: bool,
    pub line_numbers: bool,
    pub render_whitespace: bool,
}

impl Default for EditorSettings {
    fn default() -> Self {
        Self {
            tab_size: 2,
            insert_spaces: true,
            word_wrap: "off".to_string(),
            minimap_enabled: false,
            line_numbers: true,
            render_whitespace: false,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TerminalSettings {
    pub shell: String,
    pub font_size: u32,
    pub scrollback: u32,
}

impl Default for TerminalSettings {
    fn default() -> Self {
        Self {
            shell: std::env::var("SHELL").unwrap_or_else(|_| "/bin/zsh".to_string()),
            font_size: 13,
            scrollback: 10000,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UiSettings {
    pub activity_bar_visible: bool,
    pub status_bar_visible: bool,
    pub sidebar_width: u32,
}

impl Default for UiSettings {
    fn default() -> Self {
        Self {
            activity_bar_visible: true,
            status_bar_visible: true,
            sidebar_width: 52,
        }
    }
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            theme: ThemeSettings::default(),
            keyboard_shortcuts: KeyboardShortcuts::default(),
            editor: EditorSettings::default(),
            terminal: TerminalSettings::default(),
            ui: UiSettings::default(),
        }
    }
}

pub struct Settings;

impl Settings {
    fn get_settings_path() -> PathBuf {
        Self::get_config_dir().join("settings.json")
    }

    fn get_config_dir() -> PathBuf {
        dirs::config_local_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("codnia")
    }

    pub fn load() -> Result<AppSettings, String> {
        let path = Self::get_settings_path();
        if !path.exists() {
            return Ok(AppSettings::default());
        }
        let content = fs::read_to_string(&path).map_err(|e| e.to_string())?;
        serde_json::from_str(&content).map_err(|e| e.to_string())
    }

    pub fn save(settings: &AppSettings) -> Result<(), String> {
        let path = Self::get_settings_path();
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        }
        let content = serde_json::to_string_pretty(settings).map_err(|e| e.to_string())?;
        fs::write(&path, content).map_err(|e| e.to_string())
    }

    pub fn get_shortcuts() -> Result<KeyboardShortcuts, String> {
        let settings = Self::load()?;
        Ok(settings.keyboard_shortcuts)
    }

    pub fn update_shortcut(action: String, shortcut: String) -> Result<(), String> {
        let mut settings = Self::load()?;
        let old_shortcut = settings
            .keyboard_shortcuts
            .shortcuts
            .iter()
            .find(|(_, v)| *v == &action)
            .map(|(k, _)| k.clone());
        if let Some(old) = old_shortcut {
            settings.keyboard_shortcuts.shortcuts.remove(&old);
        }
        settings.keyboard_shortcuts.shortcuts.insert(shortcut, action);
        Self::save(&settings)
    }
}