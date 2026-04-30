import { useState } from "react";
import { ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";
import type { FileEntry } from "@/types";
import * as tauri from "@/lib/tauri";

interface FileTreeProps {
  entries: FileEntry[];
  onFileSelect: (path: string) => void;
}

function getFileIcon(filename: string): string {
  const ext = filename.split(".").pop()?.toLowerCase() || "";
  const icons: Record<string, string> = {
    rs: "\u{1F980}",
    ts: "\u{1F4D8}",
    tsx: "\u269B",
    js: "\u{1F4DC}",
    json: "\u{1F4CB}",
    html: "\u{1F310}",
    css: "\u{1F3A8}",
    md: "\u{1F4DD}",
    toml: "\u2699",
    yaml: "\u{1F4C4}",
    yml: "\u{1F4C4}",
    sh: "\u{1F5A5}",
    py: "\u{1F40D}",
  };
  return icons[ext] || "\u{1F4C4}";
}

function TreeNode({
  entry,
  onFileSelect,
  depth = 0,
}: {
  entry: FileEntry;
  onFileSelect: (path: string) => void;
  depth?: number;
}) {
  const [expanded, setExpanded] = useState(false);
  const [children, setChildren] = useState<FileEntry[]>([]);
  const [loaded, setLoaded] = useState(false);
  const [activeFile, setActiveFile] = useState<string | null>(null);

  const handleClick = async () => {
    if (entry.is_directory) {
      if (!loaded) {
        try {
          const listing = await tauri.listDirectory(entry.path);
          setChildren(listing.entries);
          setLoaded(true);
        } catch {
          // ignore
        }
      }
      setExpanded(!expanded);
    } else {
      onFileSelect(entry.path);
      setActiveFile(entry.path);
    }
  };

  return (
    <div>
      <div
        onClick={handleClick}
        className={cn(
          "flex items-center gap-2 py-1.5 px-3 rounded cursor-pointer text-[13px] transition-colors",
          "text-[#888888] hover:bg-[#222222] hover:text-white",
          activeFile === entry.path && "bg-[#2a2a2a] text-white",
        )}
        style={{ paddingLeft: `${12 + depth * 16}px` }}
      >
        {entry.is_directory ? (
          <ChevronRight
            className={cn(
              "h-3 w-3 shrink-0 transition-transform text-[#888888]",
              expanded && "rotate-90",
            )}
          />
        ) : (
          <span className="w-3 shrink-0" />
        )}
        <span className="text-sm shrink-0">
          {entry.is_directory ? (expanded ? "\u{1F4C2}" : "\u{1F4C1}") : getFileIcon(entry.name)}
        </span>
        <span className={cn("truncate", entry.is_directory && "font-medium")}>{entry.name}</span>
      </div>
      {expanded && loaded && (
        <div>
          {children.map((child) => (
            <TreeNode key={child.path} entry={child} onFileSelect={onFileSelect} depth={depth + 1} />
          ))}
        </div>
      )}
    </div>
  );
}

export function FileTree({ entries, onFileSelect }: FileTreeProps) {
  if (!entries.length) {
    return (
      <div className="px-3 py-8 text-center text-[#555555] italic text-[13px]">
        Open a project to see files
      </div>
    );
  }

  return (
    <div className="py-1 overflow-y-auto h-full">
      {entries.map((entry) => (
        <TreeNode key={entry.path} entry={entry} onFileSelect={onFileSelect} />
      ))}
    </div>
  );
}