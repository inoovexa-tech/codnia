import { useState, useRef, useEffect } from "react";
import { createPortal } from "react-dom";
import { Plus, PanelLeftOpen, PanelLeftClose, Settings, X } from "lucide-react";
import { Menu, MenuItem, PredefinedMenuItem } from "@tauri-apps/api/menu";
import { LogicalPosition } from "@tauri-apps/api/dpi";
import { cn } from "@/lib/utils";
import { removeProject, renameProject } from "@/lib/tauri";
import type { Project } from "@/types";

interface SidebarProps {
  projects: Project[];
  activeProjectId?: string;
  branches: Record<string, string>;
  expanded: boolean;
  onToggleExpand: () => void;
  onProjectSelect: (id: string) => void;
  onAddProject: () => void;
  onSettingsClick: () => void;
  onProjectRemoved?: () => void;
  onProjectRenamed?: () => void;
}

function getInitials(name: string): string {
  return name
    .split(/[\s_-]+/)
    .map((w) => w[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);
}

export function Sidebar({
  projects,
  activeProjectId,
  branches,
  expanded,
  onToggleExpand,
  onProjectSelect,
  onAddProject,
  onSettingsClick,
  onProjectRemoved,
  onProjectRenamed,
}: SidebarProps) {
  const [renameDialog, setRenameDialog] = useState<{ id: string; name: string } | null>(null);
  const [renameValue, setRenameValue] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (renameDialog) {
      setRenameValue(renameDialog.name);
      setTimeout(() => inputRef.current?.select(), 0);
    }
  }, [renameDialog]);

  const handleRenameConfirm = async () => {
    if (!renameDialog) return;
    const newName = renameValue.trim();
    if (newName && newName !== renameDialog.name) {
      try {
        await renameProject(renameDialog.id, newName);
        onProjectRenamed?.();
      } catch (err) {
        console.error("Rename failed:", err);
      }
    }
    setRenameDialog(null);
  };

  const handleProjectContextMenu = async (e: React.MouseEvent, project: Project) => {
    e.preventDefault();
    e.stopPropagation();
    try {
      const items: (MenuItem | PredefinedMenuItem)[] = [
        await MenuItem.new({
          text: "Rename",
          action: async () => {
            setRenameDialog({ id: project.id, name: project.name });
          },
        }),
        await PredefinedMenuItem.new({ item: "Separator" }),
        await MenuItem.new({
          text: "Remove",
          action: async () => {
            const confirmed = window.confirm(`Remove project "${project.name}" from Codnia?`);
            if (!confirmed) return;
            try {
              await removeProject(project.id);
              onProjectRemoved?.();
            } catch (err) {
              console.error("Remove failed:", err);
            }
          },
        }),
      ];
      const menu = await Menu.new({ items });
      await menu.popup(new LogicalPosition(e.clientX, e.clientY));
    } catch (err) {
      console.error("Context menu error:", err);
    }
  };

  return (
    <>
      <div
        className={cn(
          "bg-[#000000] border-r border-[#1a1a1a] h-full shrink-0 transition-[width] duration-200 overflow-hidden",
          expanded ? "w-[220px]" : "w-[52px]"
        )}
        style={{ display: "grid", gridTemplateRows: "1fr auto" }}
      >
        <div className="w-full overflow-y-auto" style={{ padding: expanded ? "8px 10px" : "8px 6px" }}>
          <div className={cn("flex flex-col gap-2 w-full", expanded ? "items-stretch" : "items-center")}>
            {projects.map((project) => {
              const branch = branches[project.id];
              const isActive = project.id === activeProjectId;
              const initials = getInitials(project.name);
              return (
                <div key={project.id} className="flex flex-col">
                   {!expanded ? (
                     <button
                       onClick={() => onProjectSelect(project.id)}
                      onContextMenu={(e) => handleProjectContextMenu(e, project)}
                       title={project.name}
                       className={cn(
                         "w-[36px] h-[36px] rounded-lg flex items-center justify-center transition-colors shrink-0",
                         isActive
                           ? "bg-[#0070f3] text-white"
                           : "bg-[#111111] text-white"
                       )}
                     >
                       <span className="text-[11px] font-semibold">
                         {initials}
                       </span>
                     </button>
                   ) : (
                     <button
                       onClick={() => onProjectSelect(project.id)}
                      onContextMenu={(e) => handleProjectContextMenu(e, project)}
                       title={project.name}
                      className={cn(
                        "h-auto rounded-lg flex items-center transition-colors w-full justify-start px-2 py-2 gap-3",
                        isActive
                          ? "bg-[#0070f3] text-white"
                          : "bg-[#111111] text-white"
                      )}
                    >
                      <span
                        className={cn(
                          "text-[11px] font-bold shrink-0 flex items-center justify-center rounded",
                          isActive ? "bg-white/20" : "bg-[#1a1a1a]",
                          "w-[28px] h-[28px]"
                        )}
                      >
                        {initials}
                      </span>
                      <div className="flex flex-col items-start min-w-0">
                        <span className="text-[12px] font-medium truncate w-full text-left">{project.name}</span>
                        {branch && <span className="text-[10px] opacity-60 truncate w-full text-left">{branch}</span>}
                      </div>
                    </button>
                  )}
                </div>
              );
            })}
            {expanded ? (
              <button
                onClick={onAddProject}
                title="Add Project"
                className="h-[36px] rounded-lg border border-dashed border-[#222222] flex items-center justify-center gap-2 text-white hover:border-[#0070f3] hover:text-[#0070f3] transition-colors w-full mt-1 px-3"
              >
                <Plus className="h-4 w-4" />
                <span className="text-[12px]">Add Project</span>
              </button>
            ) : (
              <button
                onClick={onAddProject}
                title="Add Project"
                className="w-[36px] h-[36px] rounded-lg border border-dashed border-[#222222] flex items-center justify-center text-white hover:border-[#0070f3] hover:text-[#0070f3] transition-colors text-lg mt-1"
              >
                <Plus className="h-4 w-4" />
              </button>
            )}
          </div>
        </div>

        <div className={cn(
          "w-full px-2 py-2 shrink-0 border-t border-[#1a1a1a]",
          expanded ? "flex items-center justify-between" : "flex flex-col items-center gap-1"
        )}>
          <button
            onClick={onSettingsClick}
            className="w-[36px] h-[36px] rounded-lg flex items-center justify-center text-white transition-colors"
             title="Settings"
          >
            <Settings className="w-5 h-5" />
          </button>
          <button
            onClick={onToggleExpand}
            className="w-[36px] h-[36px] rounded-lg flex items-center justify-center text-white transition-colors"
            title={expanded ? "Collapse Sidebar" : "Expand Sidebar"}
          >
            {expanded ? <PanelLeftClose className="h-[18px] w-[18px]" /> : <PanelLeftOpen className="h-[18px] w-[18px]" />}
          </button>
        </div>
      </div>

      {renameDialog && createPortal(
        <div
          style={{ position: "fixed", inset: 0, zIndex: 9999, display: "flex", alignItems: "center", justifyContent: "center", backgroundColor: "rgba(0,0,0,0.6)" }}
          onClick={() => setRenameDialog(null)}
        >
          <div
            style={{ backgroundColor: "#0a0a0a", border: "1px solid #2a2a2a", borderRadius: 12, boxShadow: "0 25px 50px -12px rgba(0,0,0,0.5)", width: 400, display: "flex", flexDirection: "column" }}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "20px 24px", borderBottom: "1px solid #1a1a1a" }}>
              <h3 style={{ fontSize: 15, fontWeight: 600, color: "#ffffff", margin: 0 }}>Rename Project</h3>
              <button
                onClick={() => setRenameDialog(null)}
                style={{ color: "#888888", padding: 4, borderRadius: 6, background: "transparent", border: "none", cursor: "pointer" }}
              >
                <X style={{ width: 16, height: 16 }} />
              </button>
            </div>
            <div style={{ padding: "24px" }}>
              <input
                ref={inputRef}
                value={renameValue}
                onChange={(e) => setRenameValue(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") handleRenameConfirm();
                  if (e.key === "Escape") setRenameDialog(null);
                }}
                style={{ width: "100%", height: 40, borderRadius: 8, border: "1px solid #333333", backgroundColor: "#111111", color: "#ffffff", fontSize: 14, padding: "8px 16px", outline: "none" }}
                autoFocus
              />
            </div>
            <div style={{ display: "flex", justifyContent: "flex-end", gap: 12, padding: "0 24px 24px 24px" }}>
              <button
                onClick={() => setRenameDialog(null)}
                style={{ height: 36, padding: "0 16px", borderRadius: 8, border: "1px solid #2a2a2a", backgroundColor: "transparent", color: "#aaaaaa", fontSize: 14, cursor: "pointer" }}
              >
                Cancel
              </button>
              <button
                onClick={handleRenameConfirm}
                disabled={!renameValue.trim() || renameValue.trim() === renameDialog.name}
                style={{ height: 36, padding: "0 16px", borderRadius: 8, border: "none", backgroundColor: "#0070f3", color: "#ffffff", fontSize: 14, fontWeight: 500, cursor: "pointer" }}
              >
                Rename
              </button>
            </div>
          </div>
        </div>,
        document.body
      )}
    </>
  );
}