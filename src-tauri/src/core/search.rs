use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::process::Command;
use std::time::Instant;
use walkdir::WalkDir;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchMatch {
    pub path: PathBuf,
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
    ignored_patterns: Vec<String>,
}

impl Searcher {
    pub fn new() -> Self {
        Self {
            max_depth: None,
            max_results: 1000,
            ignored_patterns: vec![
                "node_modules".to_string(),
                ".git".to_string(),
                "target".to_string(),
                "dist".to_string(),
                ".next".to_string(),
                "__pycache__".to_string(),
                "*.pyc".to_string(),
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

    pub fn search(&self, root: &PathBuf, query: &str, is_regex: bool, case_sensitive: bool) -> SearchResult {
        let start = Instant::now();
        let mut matches = Vec::new();

        let mut cmd = Command::new("rg");
        cmd.arg("--line-number")
            .arg("--color=never")
            .arg("--with-filename")
            .arg(".")
            .arg(root);

        if !case_sensitive {
            cmd.arg("--ignore-case");
        }

        if is_regex {
            cmd.arg("--regex");
        } else {
            cmd.arg("--fixed-strings");
        }

        for pattern in &self.ignored_patterns {
            cmd.arg("--glob").arg(pattern);
        }

        if let Some(depth) = self.max_depth {
            cmd.arg("--max-depth").arg(depth.to_string());
        }

        cmd.arg(query);

        match cmd.output() {
            Ok(output) => {
                let stdout = String::from_utf8_lossy(&output.stdout);
                for line in stdout.lines() {
                    if matches.len() >= self.max_results {
                        break;
                    }

                    let parts: Vec<&str> = line.splitn(2, ':').collect();
                    if parts.len() == 2 {
                        let path = PathBuf::from(parts[0]);
                        if let Some((line_num_str, line_content)) = parts[1].split_once(':') {
                            if let Ok(line_num) = line_num_str.parse::<usize>() {
                                matches.push(SearchMatch {
                                    path,
                                    line_number: line_num,
                                    line: line_content.to_string(),
                                });
                            }
                        }
                    }
                }
            }
            Err(e) => {
                tracing::warn!("Search failed: {}", e);
            }
        }

        let elapsed = start.elapsed();

        SearchResult {
            total_matches: matches.len(),
            matches,
            elapsed_ms: elapsed.as_millis() as u64,
        }
    }

    pub fn search_files(&self, root: &PathBuf, query: &str) -> Vec<PathBuf> {
        let query_lower = query.to_lowercase();
        let mut results = Vec::new();

        for entry in WalkDir::new(root)
            .follow_links(false)
            .max_depth(self.max_depth.unwrap_or(usize::MAX))
            .into_iter()
            .filter_map(|e| e.ok())
            .filter(|e| e.file_type().is_file())
        {
            if results.len() >= self.max_results {
                break;
            }

            let file_name = entry.file_name().to_string_lossy().to_lowercase();
            if file_name.contains(&query_lower) {
                results.push(entry.path().to_path_buf());
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