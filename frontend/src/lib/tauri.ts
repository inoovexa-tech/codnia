import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { open, save, message } from "@tauri-apps/plugin-dialog";
import type { Project, DirectoryListing, AppSettings } from "@/types";

export interface TerminalInstance {
  id: string;
  name: string;
  cwd: string;
}

export async function createTerminal(options?: { cwd?: string; shell?: string; command?: string }): Promise<TerminalInstance> {
  return invoke<TerminalInstance>("create_terminal", {
    cwd: options?.cwd ?? null,
    shell: options?.shell ?? null,
    command: options?.command ?? null,
  });
}

export async function writeTerminal(id: string, data: string): Promise<void> {
  return invoke("write_terminal", { id, data });
}

export async function resizeTerminal(id: string, rows: number, cols: number): Promise<void> {
  return invoke("resize_terminal", { id, rows, cols });
}

export async function killTerminal(id: string): Promise<void> {
  return invoke("kill_terminal", { id });
}

export async function listTerminals(): Promise<TerminalInstance[]> {
  return invoke<TerminalInstance[]>("list_terminals");
}

export function onTerminalData(id: string, callback: (data: string) => void) {
  return listen<string>(`terminal:${id}:data`, (event) => {
    callback(event.payload);
  });
}

export function onTerminalExit(id: string, callback: () => void) {
  return listen(`terminal:${id}:exit`, () => {
    callback();
  });
}

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

export async function copyPath(src: string, dst: string): Promise<void> {
  return invoke("copy_path", { src, dst });
}

export async function duplicatePath(path: string): Promise<string> {
  return invoke<string>("duplicate_path", { path });
}

export async function searchContent(root: string, query: string): Promise<[string, string][]> {
  return invoke("search_content", { root, query, maxResults: 100 });
}

export async function searchFiles(root: string, query: string): Promise<string[]> {
  return invoke("search_files", { root, query, maxResults: 100 });
}

export interface SearchMatchResult {
  path: string;
  line_number: number;
  line: string;
}

export interface SearchResultData {
  matches: SearchMatchResult[];
  total_matches: number;
  elapsed_ms: number;
}

export async function searchContentAdvanced(root: string, query: string, isRegex?: boolean, caseSensitive?: boolean, maxResults?: number): Promise<SearchResultData> {
  return invoke<SearchResultData>("search_content_advanced", {
    root,
    query,
    isRegex: isRegex ?? false,
    caseSensitive: caseSensitive ?? false,
    maxResults: maxResults ?? 200,
  });
}

export async function searchFilesAdvanced(root: string, query: string, maxResults?: number): Promise<string[]> {
  return invoke<string[]>("search_files_advanced", {
    root,
    query,
    maxResults: maxResults ?? 100,
  });
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

export async function openFileDialog(): Promise<string | null> {
  const selected = await open({ multiple: false, title: "Open File" });
  return selected as string | null;
}

export async function saveFileDialog(defaultPath?: string): Promise<string | null> {
  const selected = await save({ defaultPath, title: "Save File" });
  return selected as string | null;
}

export async function showAlertDialog(title: string, msg: string): Promise<void> {
  await message(msg, { title, kind: "error" });
}

export async function getGitBranch(path: string): Promise<string> {
  return invoke<string>("get_git_branch", { path });
}