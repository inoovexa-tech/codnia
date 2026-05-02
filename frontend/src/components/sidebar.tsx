import { Plus, PanelLeftOpen, PanelLeftClose, Settings } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
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
}: SidebarProps) {
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
                  <Button
                    variant="ghost"
                    onClick={() => onProjectSelect(project.id)}
                    title={project.name}
                    className={cn(
                      "w-[36px] h-[36px] rounded-lg flex items-center justify-center transition-colors shrink-0 px-0",
                      isActive
                        ? "bg-[#0070f3] text-white hover:bg-[#0070f3] hover:text-white"
                        : "bg-[#111111] text-[#888888] hover:bg-[#1a1a1a] hover:text-[#888888]"
                    )}
                  >
                    <span className="text-[11px] font-semibold">
                      {initials}
                    </span>
                  </Button>
                ) : (
                  <Button
                    variant="ghost"
                    onClick={() => onProjectSelect(project.id)}
                    title={project.name}
                    className={cn(
                      "h-auto rounded-lg flex items-center transition-colors w-full justify-start px-2 py-2 gap-3",
                      isActive
                        ? "bg-[#0070f3] text-white hover:bg-[#0070f3] hover:text-white"
                        : "bg-[#111111] text-[#888888] hover:bg-[#1a1a1a] hover:text-[#888888]"
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
                  </Button>
                )}
              </div>
            );
          })}
          {expanded ? (
            <Button
              variant="ghost"
              onClick={onAddProject}
              title="Add Project"
              className="h-[36px] rounded-lg border border-dashed border-[#222222] flex items-center justify-center gap-2 text-[#555555] hover:border-[#0070f3] hover:text-[#0070f3] transition-colors w-full mt-1 px-3"
            >
              <Plus className="h-4 w-4" />
              <span className="text-[12px]">Add Project</span>
            </Button>
          ) : (
            <Button
              variant="ghost"
              size="icon"
              onClick={onAddProject}
              title="Add Project"
              className="w-[36px] h-[36px] rounded-lg border border-dashed border-[#222222] flex items-center justify-center text-[#555555] hover:border-[#0070f3] hover:text-[#0070f3] transition-colors text-lg mt-1"
            >
              <Plus className="h-4 w-4" />
            </Button>
          )}
        </div>
      </div>

      <div className={cn(
        "w-full px-2 py-2 shrink-0 border-t border-[#1a1a1a]",
        expanded ? "flex items-center justify-between" : "flex flex-col items-center gap-1"
      )}>
        <Button
          variant="ghost"
          size="icon"
          onClick={onSettingsClick}
          className="w-[36px] h-[36px] rounded-lg flex items-center justify-center text-[#555555] hover:bg-[#1a1a1a] hover:text-[#888888] transition-colors"
          title="Settings"
        >
          <Settings className="w-5 h-5" />
        </Button>
        <Button
          variant="ghost"
          size="icon"
          onClick={onToggleExpand}
          className="w-[36px] h-[36px] rounded-lg flex items-center justify-center text-[#555555] hover:bg-[#1a1a1a] hover:text-[#888888] transition-colors"
          title={expanded ? "Collapse Sidebar" : "Expand Sidebar"}
        >
          {expanded ? <PanelLeftClose className="h-[18px] w-[18px]" /> : <PanelLeftOpen className="h-[18px] w-[18px]" />}
        </Button>
      </div>
    </div>
  );
}