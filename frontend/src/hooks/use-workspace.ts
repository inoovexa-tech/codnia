import { useState, useCallback } from "react";
import {
  getProjects,
  addProject as tauriAddProject,
  setActiveProject as tauriSetActive,
  listDirectory,
} from "@/lib/tauri";
import type { Project, FileEntry } from "@/types";

export function useWorkspace() {
  const [projects, setProjects] = useState<Project[]>([]);
  const [activeProject, setActiveProject] = useState<Project | null>(null);
  const [fileTree, setFileTree] = useState<FileEntry[]>([]);
  const [expandedFolders, setExpandedFolders] = useState<Set<string>>(new Set());

  const loadProjects = useCallback(async () => {
    try {
      const p = await getProjects();
      setProjects(p);
    } catch (e) {
      console.error("Failed to load projects:", e);
    }
  }, []);

  const addProject = useCallback(
    async (path: string) => {
      try {
        const project = await tauriAddProject(path);
        setProjects((prev) => [...prev, project]);
        setActive(project.id);
      } catch (e) {
        console.error("Failed to add project:", e);
      }
    },
    [],
  );

  const setActive = useCallback(async (id: string) => {
    try {
      await tauriSetActive(id);
      const p = projects.find((proj) => proj.id === id);
      if (p) {
        setActiveProject(p);
        const listing = await listDirectory(p.path);
        setFileTree(listing.entries);
      }
    } catch (e) {
      console.error("Failed to set active project:", e);
    }
  }, [projects]);

  const toggleFolder = useCallback(
    async (path: string) => {
      setExpandedFolders((prev) => {
        const next = new Set(prev);
        if (next.has(path)) {
          next.delete(path);
        } else {
          next.add(path);
        }
        return next;
      });
    },
    [],
  );

  return {
    projects,
    activeProject,
    fileTree,
    expandedFolders,
    loadProjects,
    addProject,
    setActive,
    toggleFolder,
  };
}