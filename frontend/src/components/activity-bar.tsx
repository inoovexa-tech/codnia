import { X } from "lucide-react";
import { ChevronRight } from "lucide-react";
import { FileTree } from "@/components/file-tree";
import type { FileEntry } from "@/types";

interface ActivityBarProps {
  activePanel: "explorer" | "api" | null;
  isOpen: boolean;
  fileTree: FileEntry[];
  onFileSelect: (path: string) => void;
  onClose: () => void;
  onToggle: (panel: "explorer" | "api" | null) => void;
}

export function ActivityBar({
  activePanel,
  isOpen,
  fileTree,
  onFileSelect,
  onClose,
}: ActivityBarProps) {
  if (!isOpen || !activePanel) return null;

  return (
    <div className="w-[280px] min-w-[280px] max-w-[600px] bg-[#111111] border-l border-[#2a2a2a] flex flex-col relative shrink-0">
      {/* Resize handle */}
      <div className="absolute left-0 top-0 bottom-0 w-1.5 cursor-ew-resize z-20 hover:bg-[#0070f3] transition-colors" />

      {/* Collapse button */}
      <button
        onClick={onClose}
        className="absolute left-[-18px] top-1/2 -translate-y-1/2 w-[14px] h-8 bg-[#111111] border border-[#2a2a2a] border-r-0 rounded-l flex items-center justify-center cursor-pointer text-[#555555] hover:bg-[#222222] hover:text-white hover:border-[#0070f3] z-15 transition-colors"
      >
        <ChevronRight className="w-2 h-2" />
      </button>

      {/* Header */}
      <div className="h-12 px-4 flex items-center gap-3 border-b border-[#2a2a2a]">
        {activePanel === "explorer" ? (
          <svg className="w-[18px] h-[18px] text-[#888888]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M3 7V17C3 18.1046 3.89543 19 5 19H19C20.1046 19 21 18.1046 21 17V9C21 7.89543 20.1046 7 19 7H12L9 3H5C3.89543 3 3 3.89543 3 5V7Z" />
          </svg>
        ) : (
          <svg className="w-[18px] h-[18px] text-[#888888]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M21 12a9 9 0 0 1-9 9m9-9a9 9 0 0 0-9-9m9 9H3m9 9a9 9 0 0 1-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 0 1 9-9" />
          </svg>
        )}
        <span className="text-[13px] font-medium text-white">
          {activePanel === "explorer" ? "Explorer" : "REST Client"}
        </span>
        <button
          onClick={onClose}
          className="ml-auto w-6 h-6 flex items-center justify-center rounded hover:bg-[#222222] text-[#555555] hover:text-white transition-colors"
        >
          <X className="h-3.5 w-3.5" />
        </button>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-auto p-2">
        {activePanel === "explorer" ? (
          <FileTree entries={fileTree} onFileSelect={onFileSelect} />
        ) : (
          <div>
            <div className="py-2 px-3 border-b border-[#2a2a2a]">
              <div className="flex items-center gap-2">
                <span className="inline-block px-2 py-0.5 rounded text-[10px] font-semibold bg-[#10b98133] text-[#10b981]">
                  GET
                </span>
                <span className="text-xs text-[#888888]">
                  <span className="text-white">/api/users</span>
                </span>
              </div>
              <p className="text-[10px] text-[#555555] mt-1">200 OK · 234ms</p>
            </div>
            <div className="py-2 px-3 border-b border-[#2a2a2a]">
              <div className="flex items-center gap-2">
                <span className="inline-block px-2 py-0.5 rounded text-[10px] font-semibold bg-[#f59e0b33] text-[#f59e0b]">
                  POST
                </span>
                <span className="text-xs text-[#888888]">
                  <span className="text-white">/api/auth/login</span>
                </span>
              </div>
              <p className="text-[10px] text-[#555555] mt-1">201 Created · 89ms</p>
            </div>
            <div className="py-2 px-3">
              <div className="flex items-center gap-2">
                <span className="inline-block px-2 py-0.5 rounded text-[10px] font-semibold bg-[#ef444433] text-[#ef4444]">
                  DELETE
                </span>
                <span className="text-xs text-[#888888]">
                  <span className="text-white">/api/sessions/:id</span>
                </span>
              </div>
              <p className="text-[10px] text-[#555555] mt-1">204 No Content · 45ms</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}