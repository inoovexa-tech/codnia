import { X, RefreshCw, FolderSearch, Files } from "lucide-react";
import { FileTree } from "@/components/file-tree";
import { GlobalSearch } from "@/components/global-search";
import type { FileEntry } from "@/types";

export type SidebarTab = "explorer" | "search";

interface ActivityBarProps {
  fileTree: FileEntry[];
  onFileSelect: (path: string) => void;
  onClose: () => void;
  onRefresh?: () => void;
  activeProjectPath?: string;
  activeTab?: SidebarTab;
  onTabChange?: (tab: SidebarTab) => void;
}

export function ActivityBar({
  fileTree,
  onFileSelect,
  onClose,
  onRefresh,
  activeProjectPath,
  activeTab = "explorer",
  onTabChange,
}: ActivityBarProps) {
  return (
    <div className="w-[320px] min-w-[320px] bg-[#0e0e0e] border-l border-[#1c1c1c] flex flex-col relative shrink-0">
      <div className="absolute left-0 top-0 bottom-0 w-1 cursor-col-resize z-20 hover:bg-[#0070f3] transition-colors" />

      <div className="flex items-center shrink-0 border-b border-[#1c1c1c]" style={{ height: 42, paddingLeft: 12, paddingRight: 8 }}>
        <div className="flex items-center gap-2">
          <button
            onClick={() => onTabChange?.("explorer")}
            className={`flex items-center gap-2 px-3 py-1.5 rounded-[5px] text-[12px] font-medium transition-colors ${
              activeTab === "explorer"
                ? "bg-[#1c1c1c] text-white"
                : "text-[#666666] hover:text-[#aaaaaa] hover:bg-[#161616]"
            }`}
            title="Explorer"
          >
            <Files className="h-4 w-4" />
            <span>Explorer</span>
          </button>
          <button
            onClick={() => onTabChange?.("search")}
            className={`flex items-center gap-2 px-3 py-1.5 rounded-[5px] text-[12px] font-medium transition-colors ${
              activeTab === "search"
                ? "bg-[#1c1c1c] text-white"
                : "text-[#666666] hover:text-[#aaaaaa] hover:bg-[#161616]"
            }`}
            title="Search"
          >
            <FolderSearch className="h-4 w-4" />
            <span>Search</span>
          </button>
        </div>

        <div className="flex-1" />

        <div className="flex items-center gap-1">
          {activeTab === "explorer" && onRefresh && (
            <button
              onClick={onRefresh}
              className="w-8 h-8 flex items-center justify-center rounded-[4px] text-[#666666] hover:text-white hover:bg-[#1c1c1c] transition-colors"
              title="Refresh"
            >
              <RefreshCw className="h-4 w-4" />
            </button>
          )}
          <button
            onClick={onClose}
            className="w-8 h-8 flex items-center justify-center rounded-[4px] text-[#666666] hover:text-white hover:bg-[#1c1c1c] transition-colors"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
      </div>

      <div className="flex-1 overflow-hidden">
        {activeTab === "explorer" ? (
          fileTree.length > 0 ? (
            <FileTree entries={fileTree} onFileSelect={onFileSelect} onRefresh={onRefresh} />
          ) : (
            <div className="flex-1 flex items-center justify-center px-6 py-12">
              <p className="text-[#444444] text-[13px] text-center">Open a project to see files</p>
            </div>
          )
        ) : (
          <GlobalSearch rootPath={activeProjectPath} onFileSelect={onFileSelect} />
        )}
      </div>
    </div>
  );
}