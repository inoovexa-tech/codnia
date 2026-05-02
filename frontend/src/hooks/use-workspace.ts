import { useState, useCallback } from "react";
import {
  getProjects,
  addProject as tauriAddProject,
  setActiveProject as tauriSetActive,
  listDirectory,
  getGitBranch,
} from "@/lib/tauri";
import type { Project, FileEntry } from "@/types";

export function useWorkspace() {
  const [projects, setProjects] = useState<Project[]>([]);
  const [activeProject, setActiveProject] = useState<Project | null>(null);
  const [fileTree, setFileTree] = useState<FileEntry[]>([]);
  const [expandedFolders, setExpandedFolders] = useState<Set<string>>(new Set());
  const [branches, setBranches] = useState<Record<string, string>>({});

  const loadProjects = useCallback(async () => {
    try {
      const p = await getProjects();
      setProjects(p);
      const branchMap: Record<string, string> = {};
      await Promise.all(
        p.map(async (proj) => {
          try {
            const branch = await getGitBranch(proj.path);
            if (branch) branchMap[proj.id] = branch;
          } catch {
            // not a git repo
          }
        }),
      );
      setBranches(branchMap);

      const previouslyActive = p.find((proj) => proj.is_active);
      if (previouslyActive) {
        setActiveProject(previouslyActive);
        try {
          const listing = await listDirectory(previouslyActive.path);
          setFileTree(listing.entries);
        } catch {
          // directory may not exist
        }
      }
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
        try {
          const branch = await getGitBranch(project.path);
          if (branch) {
            setBranches((prev) => ({ ...prev, [project.id]: branch }));
          }
        } catch {
          // not a git repo
        }
      } catch (e) {
        console.error("Failed to add project:", e);
      }
    },
    [],
  );

  const setActive = useCallback(async (id: string) => {
    try {
      await tauriSetActive(id);
      setProjects((prev) =>
        prev.map((p) => ({ ...p, is_active: p.id === id }))
      );
      const p = projects.find((proj) => proj.id === id);
      if (p) {
        setActiveProject({ ...p, is_active: true });
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

  const refreshFileTree = useCallback(async () => {
    if (activeProject) {
      try {
        const listing = await listDirectory(activeProject.path);
        setFileTree(listing.entries);
      } catch {
        // directory may not exist
      }
    }
  }, [activeProject]);

  return {
    projects,
    activeProject,
    fileTree,
    expandedFolders,
    branches,
    loadProjects,
    addProject,
    setActive,
    toggleFolder,
    refreshFileTree,
  };
}