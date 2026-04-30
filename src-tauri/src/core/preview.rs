use pulldown_cmark::{html, Options, Parser};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PreviewResult {
    pub html: String,
    pub preview_type: PreviewType,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PreviewType {
    Markdown,
    Html,
    Unknown,
}

pub struct Preview;

impl Preview {
    pub fn new() -> Self {
        Self
    }

    pub fn render_markdown(&self, content: &str) -> String {
        let mut options = Options::empty();
        options.insert(Options::ENABLE_TABLES);
        options.insert(Options::ENABLE_FOOTNOTES);
        options.insert(Options::ENABLE_STRIKETHROUGH);
        options.insert(Options::ENABLE_TASKLISTS);
        options.insert(Options::ENABLE_SMART_PUNCTUATION);

        let parser = Parser::new_ext(content, options);
        let mut html_output = String::new();
        html::push_html(&mut html_output, parser);
        html_output
    }

    pub fn get_preview_type(path: &PathBuf) -> PreviewType {
        path.extension()
            .and_then(|e| e.to_str())
            .map(|e| match e.to_lowercase().as_str() {
                "md" | "markdown" | "mdown" | "mkd" => PreviewType::Markdown,
                "html" | "htm" => PreviewType::Html,
                _ => PreviewType::Unknown,
            })
            .unwrap_or(PreviewType::Unknown)
    }

    pub fn render(&self, content: &str, preview_type: &PreviewType) -> String {
        match preview_type {
            PreviewType::Markdown => self.render_markdown(content),
            PreviewType::Html => content.to_string(),
            PreviewType::Unknown => format!("<pre>{}</pre>", content),
        }
    }
}

impl Default for Preview {
    fn default() -> Self {
        Self::new()
    }
}