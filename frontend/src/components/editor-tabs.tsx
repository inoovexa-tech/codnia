import { X } from "lucide-react";
import { cn } from "@/lib/utils";
import type { Tab } from "@/types";

interface EditorTabsProps {
  tabs: Tab[];
  activeTabId: string | null;
  onTabSelect: (id: string) => void;
  onTabClose: (id: string) => void;
  onNewTab: () => void;
}

function getFileIcon(filename: string): string {
  const ext = filename.split(".").pop()?.toLowerCase() || "";
  const icons: Record<string, string> = {
    rs: "\u{1F980}", ts: "\u{1F4D8}", tsx: "\u269B", js: "\u{1F4DC}",
    json: "\u{1F4CB}", html: "\u{1F310}", css: "\u{1F3A8}", md: "\u{1F4DD}",
    toml: "\u2699",
  };
  return icons[ext] || "";
}

export function EditorTabs({ tabs, activeTabId, onTabSelect, onTabClose, onNewTab }: EditorTabsProps) {
  return (
    <div className="h-10 bg-[#000000] border-b border-[#1a1a1a] flex items-center px-3 gap-2 shrink-0">
      <div className="flex items-center gap-0.5 flex-1 overflow-x-auto">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => onTabSelect(tab.id)}
            className={cn(
              "h-8 px-3 flex items-center gap-1.5 text-xs rounded-t border-b-2 transition-colors shrink-0",
              tab.id === activeTabId
                ? "text-text-primary border-accent-blue bg-bg-primary"
                : "text-text-secondary border-transparent hover:bg-bg-hover hover:text-text-primary",
            )}
          >
            <span className="text-[11px]">{getFileIcon(tab.name)}</span>
            <span>{tab.name}</span>
            {tab.isModified && (
              <span className="w-1.5 h-1.5 rounded-full bg-accent-yellow ml-1" />
            )}
            <span
              onClick={(e) => {
                e.stopPropagation();
                onTabClose(tab.id);
              }}
              className="ml-1 opacity-50 hover:opacity-100 text-sm leading-none"
            >
              <X className="h-3 w-3" />
            </span>
          </button>
        ))}
        <button
          onClick={onNewTab}
          className="w-7 h-7 flex items-center justify-center rounded text-text-tertiary hover:bg-bg-hover hover:text-text-primary transition-colors shrink-0"
          title="New Tab"
        >
          <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M12 5v14M5 12h14" />
          </svg>
        </button>
      </div>
    </div>
  );
}