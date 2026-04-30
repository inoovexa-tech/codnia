use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileEntry {
    pub name: String,
    pub path: PathBuf,
    pub is_directory: bool,
    pub is_hidden: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DirectoryListing {
    pub entries: Vec<FileEntry>,
    pub path: PathBuf,
}

#[derive(Debug)]
pub struct FileSystem {
    _watched_paths: Vec<PathBuf>,
}

impl FileSystem {
    pub fn new() -> Self {
        Self {
            _watched_paths: Vec::new(),
        }
    }

    pub fn list_directory(&self, path: &Path) -> Result<DirectoryListing, String> {
        if !path.exists() {
            return Err(format!("Path does not exist: {}", path.display()));
        }
        if !path.is_dir() {
            return Err(format!("Path is not a directory: {}", path.display()));
        }

        let entries: Vec<FileEntry> = std::fs::read_dir(path)
            .map_err(|e| e.to_string())?
            .filter_map(|entry| entry.ok())
            .map(|entry| {
                let file_name = entry.file_name();
                let name = file_name.to_string_lossy().to_string();
                let path = entry.path();
                let is_hidden = name.starts_with('.');
                FileEntry {
                    name,
                    path,
                    is_directory: entry.file_type().map(|ft| ft.is_dir()).unwrap_or(false),
                    is_hidden,
                }
            })
            .filter(|e| !e.is_hidden)
            .collect();

        let mut entries = entries;
        entries.sort_by(|a, b| {
            if a.is_directory && !b.is_directory {
                std::cmp::Ordering::Less
            } else if !a.is_directory && b.is_directory {
                std::cmp::Ordering::Greater
            } else {
                a.name.to_lowercase().cmp(&b.name.to_lowercase())
            }
        });

        Ok(DirectoryListing {
            entries,
            path: path.to_path_buf(),
        })
    }

    pub fn read_file(&self, path: &Path) -> Result<String, String> {
        std::fs::read_to_string(path).map_err(|e| e.to_string())
    }

    pub fn write_file(&self, path: &Path, content: String) -> Result<(), String> {
        std::fs::write(path, content).map_err(|e| e.to_string())
    }

    pub fn search_files(&self, root: &Path, query: &str, max_results: usize) -> Vec<PathBuf> {
        let query_lower = query.to_lowercase();
        let mut results = Vec::new();

        for entry in WalkDir::new(root)
            .follow_links(false)
            .into_iter()
            .filter_map(|e| e.ok())
            .filter(|e| e.file_type().is_file())
        {
            if entry.file_name().to_string_lossy().to_lowercase().contains(&query_lower) {
                results.push(entry.path().to_path_buf());
                if results.len() >= max_results {
                    break;
                }
            }
        }

        results
    }

    pub fn search_content(&self, root: &Path, query: &str, max_results: usize) -> Vec<(PathBuf, String)> {
        let query_lower = query.to_lowercase();
        let mut results = Vec::new();

        for entry in WalkDir::new(root)
            .follow_links(false)
            .into_iter()
            .filter_map(|e| e.ok())
            .filter(|e| e.file_type().is_file())
        {
            if let Ok(content) = std::fs::read_to_string(entry.path()) {
                if content.to_lowercase().contains(&query_lower) {
                    let line = content
                        .lines()
                        .find(|l| l.to_lowercase().contains(&query_lower))
                        .unwrap_or("")
                        .chars()
                        .take(200)
                        .collect::<String>();
                    results.push((entry.path().to_path_buf(), line));
                    if results.len() >= max_results {
                        break;
                    }
                }
            }
        }

        results
    }

    pub fn create_file(&self, path: &Path) -> Result<(), String> {
        if path.exists() {
            return Err(format!("File already exists: {}", path.display()));
        }
        std::fs::write(path, "").map_err(|e| e.to_string())
    }

    pub fn create_directory(&self, path: &Path) -> Result<(), String> {
        if path.exists() {
            return Err(format!("Directory already exists: {}", path.display()));
        }
        std::fs::create_dir_all(path).map_err(|e| e.to_string())
    }

    pub fn delete(&self, path: &Path) -> Result<(), String> {
        if path.is_dir() {
            std::fs::remove_dir_all(path).map_err(|e| e.to_string())
        } else {
            std::fs::remove_file(path).map_err(|e| e.to_string())
        }
    }

    pub fn rename(&self, old_path: &Path, new_path: &Path) -> Result<(), String> {
        std::fs::rename(old_path, new_path).map_err(|e| e.to_string())
    }

    #[allow(dead_code)]
    pub fn get_file_extension(&self, path: &Path) -> Option<String> {
        path.extension()
            .map(|e| e.to_string_lossy().to_lowercase())
    }

    #[allow(dead_code)]
    pub fn is_binary_file(&self, path: &Path) -> bool {
        if let Ok(metadata) = std::fs::metadata(path) {
            if metadata.len() > 1024 * 1024 {
                return true;
            }
        }

        if let Ok(bytes) = std::fs::read(path) {
            let check_len = std::cmp::min(bytes.len(), 8192);
            bytes[..check_len].iter().any(|&b| b == 0)
        } else {
            true
        }
    }
}

impl Default for FileSystem {
    fn default() -> Self {
        Self::new()
    }
}