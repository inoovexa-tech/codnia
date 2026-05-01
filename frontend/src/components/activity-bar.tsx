import { X } from "lucide-react";
import { FileTree } from "@/components/file-tree";
import type { FileEntry } from "@/types";

interface ActivityBarProps {
  fileTree: FileEntry[];
  onFileSelect: (path: string) => void;
  onClose: () => void;
}

export function ActivityBar({
  fileTree,
  onFileSelect,
  onClose,
}: ActivityBarProps) {
  return (
    <div className="w-[280px] min-w-[280px] bg-[#111111] border-l border-[#2a2a2a] flex flex-col relative shrink-0">
      <div className="absolute left-0 top-0 bottom-0 w-1.5 cursor-ew-resize z-20 hover:bg-[#0070f3] transition-colors" />

      <div className="h-12 pl-6 pr-4 flex items-center border-b border-[#2a2a2a]">
        <span className="text-[13px] font-medium text-white tracking-wide">Explorer</span>
        <button
          onClick={onClose}
          className="ml-auto w-7 h-7 flex items-center justify-center rounded hover:bg-[#222222] text-[#555555] hover:text-white transition-colors"
        >
          <X className="h-4 w-4" />
        </button>
      </div>

      <div className="flex-1 overflow-auto p-2">
        {fileTree.length > 0 ? (
          <FileTree entries={fileTree} onFileSelect={onFileSelect} />
        ) : (
          <p className="text-[#555555] text-[13px] px-3 py-8 text-center italic">Open a project to see files</p>
        )}
      </div>
    </div>
  );
}