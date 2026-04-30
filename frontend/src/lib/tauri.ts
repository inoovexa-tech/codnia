import { invoke } from "@tauri-apps/api/core";
import { open } from "@tauri-apps/plugin-dialog";
import type { Project, DirectoryListing, AppSettings } from "@/types";

export async function getProjects(): Promise<Project[]> {
  return invoke<Project[]>("get_projects");
}

export async function addProject(path: string): Promise<Project> {
  return invoke<Project>("add_project", { path });
}

export async function removeProject(id: string): Promise<void> {
  return invoke("remove_project", { id });
}

export async function setActiveProject(id: string): Promise<void> {
  return invoke("set_active_project", { id });
}

export async function getRecentProjects(): Promise<string[]> {
  return invoke<string[]>("get_recent_projects");
}

export async function listDirectory(path: string): Promise<DirectoryListing> {
  return invoke<DirectoryListing>("list_directory", { path });
}

export async function readFile(path: string): Promise<string> {
  return invoke<string>("read_file", { path });
}

export async function writeFile(path: string, content: string): Promise<void> {
  return invoke("write_file", { path, content });
}

export async function createFile(path: string): Promise<void> {
  return invoke("create_file", { path });
}

export async function createDirectory(path: string): Promise<void> {
  return invoke("create_directory", { path });
}

export async function deletePath(path: string): Promise<void> {
  return invoke("delete_path", { path });
}

export async function renamePath(oldPath: string, newPath: string): Promise<void> {
  return invoke("rename_path", { oldPath, newPath });
}

export async function searchContent(root: string, query: string): Promise<[string, string][]> {
  return invoke("search_content", { root, query, maxResults: 100 });
}

export async function getSettings(): Promise<AppSettings> {
  return invoke<AppSettings>("get_settings");
}

export async function saveSettings(settings: AppSettings): Promise<void> {
  return invoke("save_settings", { settings });
}

export async function openFolderDialog(): Promise<string | null> {
  const selected = await open({ directory: true, multiple: false, title: "Select Project Folder" });
  return selected as string | null;
}