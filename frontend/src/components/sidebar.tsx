import { Plus } from "lucide-react";
import { cn } from "@/lib/utils";
import type { Project } from "@/types";

interface SidebarProps {
  projects: Project[];
  activeProjectId?: string;
  onProjectSelect: (id: string) => void;
  onAddProject: () => void;
  onExplorerClick: () => void;
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
  onProjectSelect,
  onAddProject,
  onExplorerClick,
  onSettingsClick,
}: SidebarProps) {
  return (
    <div className="w-[52px] bg-[#111111] border-r border-[#2a2a2a] flex flex-col items-center py-2 gap-1 shrink-0">
      <div className="flex flex-col items-center gap-1 w-full px-2">
        {projects.map((project) => (
          <button
            key={project.id}
            onClick={() => onProjectSelect(project.id)}
            title={project.name}
            className={cn(
              "w-[36px] h-[36px] rounded-lg flex items-center justify-center text-[11px] font-semibold transition-colors",
              project.id === activeProjectId
                ? "bg-[#0070f3] text-white"
                : "bg-[#1a1a1a] text-[#888888] hover:bg-[#222222]",
            )}
          >
            {getInitials(project.name)}
          </button>
        ))}
        <button
          onClick={onAddProject}
          title="Add Project"
          className="w-[36px] h-[36px] rounded-lg border border-dashed border-[#333333] flex items-center justify-center text-[#555555] hover:border-[#0070f3] hover:text-[#0070f3] transition-colors text-lg mt-1"
        >
          <Plus className="h-4 w-4" />
        </button>
      </div>

      <div className="flex-1" />

      <div className="flex flex-col items-center gap-1 w-full px-2">
        <button
          onClick={onExplorerClick}
          className="w-[36px] h-[36px] rounded-lg flex items-center justify-center text-[#555555] hover:bg-[#222222] hover:text-[#888888] transition-colors"
          title="Explorer"
        >
          <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" />
          </svg>
        </button>
        <button
          onClick={onSettingsClick}
          className="w-[36px] h-[36px] rounded-lg flex items-center justify-center text-[#555555] hover:bg-[#222222] hover:text-[#888888] transition-colors"
          title="Settings"
        >
          <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="3" />
            <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9c.26.604.852.997 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
          </svg>
        </button>
      </div>
    </div>
  );
}