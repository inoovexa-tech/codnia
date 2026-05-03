use serde::{Deserialize, Serialize};
use std::path::Path;
use std::process::Command;
use std::time::Instant;
use walkdir::WalkDir;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchMatch {
    pub path: String,
    pub line_number: usize,
    pub line: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResult {
    pub matches: Vec<SearchMatch>,
    pub total_matches: usize,
    pub elapsed_ms: u64,
}

#[derive(Debug, Clone)]
pub struct Searcher {
    max_depth: Option<usize>,
    max_results: usize,
    ignored_dirs: Vec<String>,
}

impl Searcher {
    pub fn new() -> Self {
        Self {
            max_depth: None,
            max_results: 1000,
            ignored_dirs: vec![
                "node_modules".to_string(),
                ".git".to_string(),
                "target".to_string(),
                "dist".to_string(),
                ".next".to_string(),
                "__pycache__".to_string(),
                ".venv".to_string(),
                "venv".to_string(),
                "build".to_string(),
                "out".to_string(),
                ".bundle".to_string(),
                "vendor".to_string(),
            ],
        }
    }

    #[allow(dead_code)]
    pub fn with_max_depth(mut self, depth: usize) -> Self {
        self.max_depth = Some(depth);
        self
    }

    pub fn with_max_results(mut self, max: usize) -> Self {
        self.max_results = max;
        self
    }

    pub fn search(&self, root: &Path, query: &str, is_regex: bool, case_sensitive: bool) -> SearchResult {
        let start = Instant::now();
        let matches = if let Ok(rg_results) = self.search_with_rg(root, query, is_regex, case_sensitive) {
            rg_results
        } else {
            self.search_fallback(root, query, case_sensitive)
        };
        let elapsed = start.elapsed();

        SearchResult {
            total_matches: matches.len(),
            matches,
            elapsed_ms: elapsed.as_millis() as u64,
        }
    }

    fn search_with_rg(&self, root: &Path, query: &str, is_regex: bool, case_sensitive: bool) -> Result<Vec<SearchMatch>, String> {
        let mut cmd = Command::new("rg");
        cmd.arg("--line-number")
            .arg("--color=never")
            .arg("--no-heading")
            .arg("--with-filename")
            .arg("--max-count")
            .arg("50");

        if !case_sensitive {
            cmd.arg("--ignore-case");
        }

        if is_regex {
            cmd.arg("--regexp");
        } else {
            cmd.arg("--fixed-strings");
        }

        for dir in &self.ignored_dirs {
            cmd.arg("--glob").arg(format!("!{}", dir));
        }

        if let Some(depth) = self.max_depth {
            cmd.arg("--max-depth").arg(depth.to_string());
        }

        cmd.arg("--max-filesize").arg("1M");
        cmd.arg(query).arg(root);

        let output = cmd.output().map_err(|e| format!("rg not available: {}", e))?;

        if !output.status.success() && output.stdout.is_empty() {
            return Ok(Vec::new());
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let mut matches = Vec::new();

        for line in stdout.lines() {
            if matches.len() >= self.max_results {
                break;
            }

            let line_trimmed = line.trim();
            if line_trimmed.is_empty() {
                continue;
            }

            let parts: Vec<&str> = line_trimmed.splitn(3, ':').collect();
            if parts.len() >= 3 {
                let path = parts[0].to_string();
                if let Ok(line_num) = parts[1].parse::<usize>() {
                    let content = parts[2].to_string();
                    let truncated: String = content.chars().take(300).collect();
                    matches.push(SearchMatch {
                        path,
                        line_number: line_num,
                        line: truncated,
                    });
                }
            }
        }

        Ok(matches)
    }

    fn search_fallback(&self, root: &Path, query: &str, case_sensitive: bool) -> Vec<SearchMatch> {
        let query_lower = query.to_lowercase();
        let mut matches = Vec::new();

        for entry in WalkDir::new(root)
            .follow_links(false)
            .into_iter()
            .filter_map(|e| e.ok())
        {
            if matches.len() >= self.max_results {
                break;
            }

            let path = entry.path();
            if !path.is_file() {
                continue;
            }

            if let Some(name) = path.file_name() {
                let name_str = name.to_string_lossy();
                if name_str.starts_with('.') {
                    continue;
                }
            }

            if let Some(parent) = path.parent() {
                let parent_str = parent.to_string_lossy();
                let is_ignored = self.ignored_dirs.iter().any(|dir| {
                    parent_str.contains(&format!("/{}", dir)) || parent_str.contains(&format!("\\{}", dir))
                });
                if is_ignored {
                    continue;
                }
            }

            if let Ok(metadata) = std::fs::metadata(path) {
                if metadata.len() > 1024 * 1024 {
                    continue;
                }
            }

            let content = match std::fs::read_to_string(path) {
                Ok(c) => c,
                Err(_) => continue,
            };

            if content.contains('\0') {
                continue;
            }

            let mut count = 0;
            for (line_num, line) in content.lines().enumerate() {
                if matches.len() >= self.max_results || count >= 50 {
                    break;
                }
                let matches_query = if case_sensitive {
                    line.contains(query)
                } else {
                    line.to_lowercase().contains(&query_lower)
                };
                if matches_query {
                    let truncated: String = line.chars().take(300).collect();
                    matches.push(SearchMatch {
                        path: path.to_string_lossy().to_string(),
                        line_number: line_num + 1,
                        line: truncated,
                    });
                    count += 1;
                }
            }
        }

        matches
    }

    pub fn search_files(&self, root: &Path, query: &str) -> Vec<String> {
        let query_lower = query.to_lowercase();
        let mut results = Vec::new();

        for entry in WalkDir::new(root)
            .follow_links(false)
            .into_iter()
            .filter_map(|e| e.ok())
        {
            if results.len() >= self.max_results {
                break;
            }

            let path = entry.path();
            if !path.is_file() {
                continue;
            }

            if let Some(name) = path.file_name() {
                let name_str = name.to_string_lossy();
                if name_str.starts_with('.') {
                    continue;
                }
            }

            if let Some(parent) = path.parent() {
                let parent_str = parent.to_string_lossy();
                let is_ignored = self.ignored_dirs.iter().any(|dir| {
                    parent_str.contains(&format!("/{}", dir)) || parent_str.contains(&format!("\\{}", dir))
                });
                if is_ignored {
                    continue;
                }
            }

            if entry.file_name().to_string_lossy().to_lowercase().contains(&query_lower) {
                results.push(path.to_string_lossy().to_string());
            }
        }

        results
    }
}

impl Default for Searcher {
    fn default() -> Self {
        Self::new()
    }
}