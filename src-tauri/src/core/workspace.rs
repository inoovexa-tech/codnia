use crate::core::persistence::{Persistence, WorkspaceStore, StoredProject, StoredTab};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Project {
    pub id: Uuid,
    pub name: String,
    pub path: PathBuf,
    pub is_active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkspaceRoot {
    pub id: Uuid,
    pub name: String,
    pub path: PathBuf,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkspaceState {
    pub id: Uuid,
    pub name: String,
    pub path: PathBuf,
    pub roots: Vec<WorkspaceRoot>,
    pub open_files: Vec<PathBuf>,
    pub active_file: Option<PathBuf>,
    pub expanded_folders: Vec<PathBuf>,
}

#[derive(Debug, Default)]
pub struct WorkspaceManager {
    projects: HashMap<Uuid, Project>,
    workspaces: HashMap<Uuid, WorkspaceState>,
    active_workspace_id: Option<Uuid>,
    recent_projects: Vec<PathBuf>,
}

impl WorkspaceManager {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn load_from_disk() -> Result<Self, String> {
        let workspace_store = Persistence::load_workspace()?;

        let mut manager = Self::new();

        for stored_project in workspace_store.projects {
            if let Ok(id) = Uuid::parse_str(&stored_project.id) {
                let path = PathBuf::from(&stored_project.path);
                if path.exists() {
                    let project = Project {
                        id,
                        name: stored_project.name,
                        path,
                        is_active: stored_project.is_active,
                    };
                    if project.is_active {
                        manager.active_workspace_id = Some(project.id);
                    }
                    manager.projects.insert(project.id, project);
                }
            }
        }

        for tab in workspace_store.open_tabs {
            if let Some(active_ws) = manager.active_workspace_id {
                if let Some(ws) = manager.workspaces.get_mut(&active_ws) {
                    ws.open_files.push(PathBuf::from(&tab.path));
                    if ws.active_file.is_none() {
                        ws.active_file = Some(PathBuf::from(&tab.path));
                    }
                }
            }
        }

        manager.recent_projects = workspace_store.recent_projects
            .into_iter()
            .map(PathBuf::from)
            .collect();

        Ok(manager)
    }

    pub fn save_to_disk(&self) -> Result<(), String> {
        let projects: Vec<StoredProject> = self.projects.values()
            .map(|p| StoredProject {
                id: p.id.to_string(),
                name: p.name.clone(),
                path: p.path.to_string_lossy().to_string(),
                is_active: p.is_active,
            })
            .collect();

        let open_tabs: Vec<StoredTab> = self.get_active_workspace()
            .map(|ws| ws.open_files.iter().map(|p| StoredTab {
                id: format!("tab-{}", p.to_string_lossy()),
                path: p.to_string_lossy().to_string(),
                name: p.file_name()
                    .map(|n| n.to_string_lossy().to_string())
                    .unwrap_or_default(),
                is_modified: false,
                scroll_position: None,
                cursor_position: None,
            }).collect())
            .unwrap_or_default();

        let _recent_projects: Option<Vec<String>> = if self.recent_projects.is_empty() {
            None
        } else {
            Some(self.recent_projects.iter()
                .map(|p| p.to_string_lossy().to_string())
                .collect())
        };

        let workspace_store = WorkspaceStore {
            projects,
            open_tabs,
            expanded_folders: Vec::new(),
            recent_projects: Vec::new(),
        };

        Persistence::save_workspace(&workspace_store)?;

        for project in self.projects.values() {
            Persistence::add_recent_project(
                project.path.to_string_lossy().to_string(),
                project.name.clone()
            )?;
        }

        Ok(())
    }

    pub fn add_project(&mut self, path: PathBuf) -> Result<Project, String> {
        if !path.exists() {
            return Err(format!("Path does not exist: {}", path.display()));
        }
        if !path.is_dir() {
            return Err(format!("Path is not a directory: {}", path.display()));
        }

        let name = path
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_else(|| "Unknown".to_string());

        let project = Project {
            id: Uuid::new_v4(),
            name,
            path: path.clone(),
            is_active: false,
        };

        self.projects.insert(project.id, project.clone());
        self.add_to_recent(path);
        let _ = self.save_to_disk();

        Ok(project)
    }

    pub fn remove_project(&mut self, id: Uuid) -> Option<Project> {
        let removed = self.projects.remove(&id);
        if removed.is_some() {
            let _ = self.save_to_disk();
        }
        removed
    }

    #[allow(dead_code)]
    pub fn get_project(&self, id: Uuid) -> Option<&Project> {
        self.projects.get(&id)
    }

    pub fn get_all_projects(&self) -> Vec<&Project> {
        self.projects.values().collect()
    }

    pub fn set_active_project(&mut self, id: Uuid) -> Result<(), String> {
        for project in self.projects.values_mut() {
            project.is_active = project.id == id;
        }

        if let Some(project) = self.projects.get(&id) {
            let workspace_id = Uuid::new_v4();
            let root = WorkspaceRoot {
                id: Uuid::new_v4(),
                name: project.name.clone(),
                path: project.path.clone(),
            };
            let workspace = WorkspaceState {
                id: workspace_id,
                name: project.name.clone(),
                path: project.path.clone(),
                roots: vec![root],
                open_files: Vec::new(),
                active_file: None,
                expanded_folders: Vec::new(),
            };
            self.workspaces.insert(workspace_id, workspace);
            self.active_workspace_id = Some(workspace_id);
            let _ = self.save_to_disk();
        }

        Ok(())
    }

    pub fn add_workspace_root(&mut self, root_path: PathBuf) -> Result<WorkspaceRoot, String> {
        if !root_path.exists() {
            return Err(format!("Path does not exist: {}", root_path.display()));
        }
        if !root_path.is_dir() {
            return Err(format!("Path is not a directory: {}", root_path.display()));
        }

        let workspace = self.get_active_workspace_mut();

        if let Some(ws) = workspace {
            let name = root_path
                .file_name()
                .map(|n| n.to_string_lossy().to_string())
                .unwrap_or_else(|| "Unknown".to_string());

            let root = WorkspaceRoot {
                id: Uuid::new_v4(),
                name,
                path: root_path.clone(),
            };

            ws.roots.push(root.clone());
            ws.path = ws.roots.first().map(|r| r.path.clone()).unwrap_or_default();
            let _ = self.save_to_disk();

            Ok(root)
        } else {
            Err("No active workspace".to_string())
        }
    }

    pub fn remove_workspace_root(&mut self, root_id: Uuid) -> Result<(), String> {
        if let Some(ws) = self.get_active_workspace_mut() {
            if ws.roots.len() <= 1 {
                return Err("Cannot remove the last root from workspace".to_string());
            }
            ws.roots.retain(|r| r.id != root_id);
            ws.path = ws.roots.first().map(|r| r.path.clone()).unwrap_or_default();
            let _ = self.save_to_disk();
            Ok(())
        } else {
            Err("No active workspace".to_string())
        }
    }

    pub fn get_workspace_roots(&self) -> Vec<WorkspaceRoot> {
        self.get_active_workspace()
            .map(|ws| ws.roots.clone())
            .unwrap_or_default()
    }

    pub fn get_active_workspace(&self) -> Option<&WorkspaceState> {
        self.active_workspace_id.and_then(|id| self.workspaces.get(&id))
    }

    pub fn get_active_workspace_mut(&mut self) -> Option<&mut WorkspaceState> {
        self.active_workspace_id.and_then(|id| self.workspaces.get_mut(&id))
    }

    fn add_to_recent(&mut self, path: PathBuf) {
        self.recent_projects.retain(|p| p != &path);
        self.recent_projects.insert(0, path);
        if self.recent_projects.len() > 10 {
            self.recent_projects.truncate(10);
        }
    }

    pub fn get_recent_projects(&self) -> &[PathBuf] {
        &self.recent_projects
    }
}