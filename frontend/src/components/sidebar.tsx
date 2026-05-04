import { Plus, PanelLeftOpen, PanelLeftClose, Settings } from "lucide-react";
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
  const handleProjectContextMenu = async (e: React.MouseEvent, project: Project) => {
    e.preventDefault();
    e.stopPropagation();
    try {
      const items: (MenuItem | PredefinedMenuItem)[] = [
        await MenuItem.new({
          text: "Rename",
          action: async () => {
            const newName = window.prompt("Rename project:", project.name);
            if (newName && newName.trim() && newName.trim() !== project.name) {
              try {
                await renameProject(project.id, newName.trim());
                onProjectRenamed?.();
              } catch (err) {
                console.error("Rename failed:", err);
              }
            }
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
  );
}