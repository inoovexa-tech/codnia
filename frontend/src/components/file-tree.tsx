import { useState, useCallback, useRef, useEffect } from "react";
import {
  ChevronRight,
  ChevronDown,
  File,
  Folder,
  FolderOpen,
  FolderPlus,
  FilePlus,
} from "lucide-react";
import { Menu, MenuItem, PredefinedMenuItem } from "@tauri-apps/api/menu";
import { LogicalPosition } from "@tauri-apps/api/dpi";
import { cn } from "@/lib/utils";
import * as tauri from "@/lib/tauri";
import type { FileEntry } from "@/types";

interface FileTreeProps {
  entries: FileEntry[];
  onFileSelect: (path: string) => void;
  onRefresh?: () => void;
}

interface ClipboardItem {
  path: string;
  name: string;
  is_directory: boolean;
  operation: "copy" | "cut";
}

type InlineEdit = {
  type: "rename";
  path: string;
  originalName: string;
  parentPath: string;
} | {
  type: "new-file" | "new-dir";
  parentPath: string;
};

export function FileTree({ entries, onFileSelect, onRefresh }: FileTreeProps) {
  const [clipboard, setClipboard] = useState<ClipboardItem | null>(null);
  const [draggedPath, setDraggedPath] = useState<string | null>(null);
  const [inlineEdit, setInlineEdit] = useState<InlineEdit | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);

  const handleRefresh = useCallback(async () => {
    onRefresh?.();
    setRefreshKey((k) => k + 1);
  }, [onRefresh]);

  const handleDelete = useCallback(
    async (entry: FileEntry) => {
      const confirmed = window.confirm(
        `Delete ${entry.is_directory ? "folder" : "file"} "${entry.name}"?${entry.is_directory ? " This will delete all contents." : ""}`
      );
      if (!confirmed) return;
      try {
        await tauri.deletePath(entry.path);
        handleRefresh();
      } catch (e) {
        console.error("Delete failed:", e);
      }
    },
    [handleRefresh]
  );

  const handleRename = useCallback((entry: FileEntry) => {
    const parentPath = entry.is_directory
      ? entry.path
      : entry.path.substring(0, entry.path.lastIndexOf("/"));
    setInlineEdit({
      type: "rename",
      path: entry.path,
      originalName: entry.name,
      parentPath,
    });
  }, []);

  const handleDuplicate = useCallback(
    async (entry: FileEntry) => {
      try {
        await tauri.duplicatePath(entry.path);
        handleRefresh();
      } catch (e) {
        console.error("Duplicate failed:", e);
      }
    },
    [handleRefresh]
  );

  const handleCopy = useCallback((entry: FileEntry) => {
    setClipboard({ path: entry.path, name: entry.name, is_directory: entry.is_directory, operation: "copy" });
  }, []);

  const handleCut = useCallback((entry: FileEntry) => {
    setClipboard({ path: entry.path, name: entry.name, is_directory: entry.is_directory, operation: "cut" });
  }, []);

  const handlePaste = useCallback(
    async (targetDir: string) => {
      if (!clipboard) return;
      const dst = `${targetDir}/${clipboard.name}`;
      if (clipboard.operation === "copy") {
        try {
          await tauri.copyPath(clipboard.path, dst);
          handleRefresh();
        } catch (e) {
          console.error("Paste (copy) failed:", e);
        }
      } else {
        try {
          await tauri.renamePath(clipboard.path, dst);
          setClipboard(null);
          handleRefresh();
        } catch (e) {
          console.error("Paste (cut) failed:", e);
        }
      }
    },
    [clipboard, handleRefresh]
  );

  const handleNewFile = useCallback((parentPath: string) => {
    setInlineEdit({ type: "new-file", parentPath });
  }, []);

  const handleNewDir = useCallback((parentPath: string) => {
    setInlineEdit({ type: "new-dir", parentPath });
  }, []);

  const handleContextMenu = useCallback(
    async (e: React.MouseEvent, entry: FileEntry) => {
      e.preventDefault();
      e.stopPropagation();

      const getParentPath = (ent: FileEntry) =>
        ent.is_directory ? ent.path : ent.path.substring(0, ent.path.lastIndexOf("/"));

      try {
        const items: (MenuItem | PredefinedMenuItem)[] = [
          await MenuItem.new({ text: "New File", action: () => handleNewFile(getParentPath(entry)) }),
          await MenuItem.new({ text: "New Folder", action: () => handleNewDir(getParentPath(entry)) }),
          await PredefinedMenuItem.new({ item: "Separator" }),
          await MenuItem.new({ text: "Rename", accelerator: "F2", action: () => handleRename(entry) }),
          await MenuItem.new({ text: "Delete", accelerator: "Del", action: () => handleDelete(entry) }),
          await MenuItem.new({ text: "Duplicate", action: () => handleDuplicate(entry) }),
          await PredefinedMenuItem.new({ item: "Separator" }),
          await MenuItem.new({ text: "Copy", accelerator: "CmdOrCtrl+C", action: () => handleCopy(entry) }),
          await MenuItem.new({ text: "Cut", accelerator: "CmdOrCtrl+X", action: () => handleCut(entry) }),
        ];

        if (clipboard) {
          const pasteTarget = entry.is_directory ? entry.path : getParentPath(entry);
          items.push(await MenuItem.new({ text: "Paste", accelerator: "CmdOrCtrl+V", action: () => handlePaste(pasteTarget) }));
        }

        const menu = await Menu.new({ items });
        await menu.popup(new LogicalPosition(e.clientX, e.clientY));
      } catch (err) {
        console.error("Context menu error:", err);
      }
    },
    [handleNewFile, handleNewDir, handleRename, handleDelete, handleDuplicate, handleCopy, handleCut, handlePaste, clipboard]
  );

  const handleDragStart = useCallback((e: React.DragEvent, entry: FileEntry) => {
    e.dataTransfer.setData("text/plain", entry.path);
    e.dataTransfer.effectAllowed = "copy";
    setDraggedPath(entry.path);
  }, []);

  const handleDragEnd = useCallback(() => {
    setDraggedPath(null);
  }, []);

  if (!entries.length) {
    return (
      <div className="px-3 py-8 text-center text-[#555555] italic text-[13px]">
        Open a project to see files
      </div>
    );
  }

  const rootPath = entries.length > 0 ? entries[0].path.substring(0, entries[0].path.lastIndexOf("/")) : "";
  const isRootNewFile = inlineEdit?.type === "new-file" && inlineEdit.parentPath === rootPath;
  const isRootNewDir = inlineEdit?.type === "new-dir" && inlineEdit.parentPath === rootPath;
  const rootNewInline = isRootNewFile || isRootNewDir ? inlineEdit : null;

  return (
    <div className="py-1 overflow-y-auto h-full" onContextMenu={async (e) => {
      e.preventDefault();
      const parentPath = rootPath || "";
      if (!parentPath) return;
      try {
        const items: (MenuItem | PredefinedMenuItem)[] = [
          await MenuItem.new({ text: "New File", action: () => handleNewFile(parentPath) }),
          await MenuItem.new({ text: "New Folder", action: () => handleNewDir(parentPath) }),
        ];
        const menu = await Menu.new({ items });
        await menu.popup(new LogicalPosition(e.clientX, e.clientY));
      } catch (err) {
        console.error("Context menu error:", err);
      }
    }}>
      {rootNewInline && (
        <div
          className="flex items-center gap-1.5 py-[3px] px-3"
          style={{ paddingLeft: `${12}px` }}
        >
          <span className="w-4 shrink-0" />
          {rootNewInline.type === "new-dir" ? (
            <Folder className="h-4 w-4 shrink-0 text-[#e8a438] opacity-50" />
          ) : (
            <File className="h-4 w-4 shrink-0 text-text-secondary opacity-50" />
          )}
          <InlineEditInput
            defaultValue=""
            onConfirm={async (value: string) => {
              if (!rootNewInline) return;
              try {
                if (rootNewInline.type === "new-file") {
                  await tauri.createFile(`${rootNewInline.parentPath}/${value}`);
                } else {
                  await tauri.createDirectory(`${rootNewInline.parentPath}/${value}`);
                }
                handleRefresh();
              } catch (e) {
                console.error("Create failed:", e);
              }
              setInlineEdit(null);
            }}
            onCancel={() => setInlineEdit(null)}
          />
        </div>
      )}
      {entries.map((entry) => (
        <TreeNode
          key={entry.path}
          entry={entry}
          onFileSelect={onFileSelect}
          depth={0}
          onContextMenu={handleContextMenu}
          onDragStart={handleDragStart}
          onDragEnd={handleDragEnd}
          draggedPath={draggedPath}
          onNewFile={handleNewFile}
          onNewDir={handleNewDir}
          inlineEdit={inlineEdit}
          onInlineEditConfirm={async (value: string) => {
            if (!inlineEdit) return;
            try {
              if (inlineEdit.type === "rename") {
                const newPath = `${inlineEdit.parentPath}/${value}`;
                if (value && value !== inlineEdit.originalName) {
                  await tauri.renamePath(inlineEdit.path, newPath);
                }
              } else if (inlineEdit.type === "new-file") {
                await tauri.createFile(`${inlineEdit.parentPath}/${value}`);
              } else if (inlineEdit.type === "new-dir") {
                await tauri.createDirectory(`${inlineEdit.parentPath}/${value}`);
              }
              handleRefresh();
            } catch (e) {
              console.error("Inline edit failed:", e);
            }
            setInlineEdit(null);
          }}
          onInlineEditCancel={() => setInlineEdit(null)}
          refreshKey={refreshKey}
        />
      ))}
    </div>
  );
}

function InlineEditInput({
  defaultValue,
  onConfirm,
  onCancel,
}: {
  defaultValue: string;
  onConfirm: (value: string) => void;
  onCancel: () => void;
}) {
  const [value, setValue] = useState(defaultValue);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const el = inputRef.current;
    if (el) {
      el.focus();
      const dotIdx = defaultValue.lastIndexOf(".");
      if (dotIdx > 0) {
        el.setSelectionRange(0, dotIdx);
      } else {
        el.select();
      }
    }
  }, [defaultValue]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") {
      e.stopPropagation();
      if (value.trim()) onConfirm(value.trim());
      else onCancel();
    } else if (e.key === "Escape") {
      e.stopPropagation();
      onCancel();
    }
  };

  return (
    <input
      ref={inputRef}
      value={value}
      onChange={(e) => setValue(e.target.value)}
      onKeyDown={handleKeyDown}
      onBlur={() => {
        if (value.trim()) onConfirm(value.trim());
        else onCancel();
      }}
      className="flex-1 min-w-0 bg-[#0c0c0c] border border-[#0070f3] rounded px-1 py-0 text-[13px] text-white outline-none"
      onClick={(e) => e.stopPropagation()}
    />
  );
}

function TreeNode({
  entry,
  onFileSelect,
  depth,
  onContextMenu,
  onDragStart,
  onDragEnd,
  draggedPath,
  onNewFile,
  onNewDir,
  inlineEdit,
  onInlineEditConfirm,
  onInlineEditCancel,
  refreshKey,
}: {
  entry: FileEntry;
  onFileSelect: (path: string) => void;
  depth: number;
  onContextMenu: (e: React.MouseEvent, entry: FileEntry) => void;
  onDragStart: (e: React.DragEvent, entry: FileEntry) => void;
  onDragEnd: () => void;
  draggedPath: string | null;
  onNewFile: (parentPath: string) => void;
  onNewDir: (parentPath: string) => void;
  inlineEdit: InlineEdit | null;
  onInlineEditConfirm: (value: string) => void;
  onInlineEditCancel: () => void;
  refreshKey: number;
}) {
  const [expanded, setExpanded] = useState(false);
  const [children, setChildren] = useState<FileEntry[]>([]);
  const [loaded, setLoaded] = useState(false);
  const prevRefreshKey = useRef(refreshKey);

  useEffect(() => {
    if (refreshKey !== prevRefreshKey.current && loaded) {
      prevRefreshKey.current = refreshKey;
      tauri.listDirectory(entry.path).then((listing) => {
        setChildren(listing.entries);
      }).catch(() => {});
    }
  }, [refreshKey, loaded, entry.path]);

  const isRenaming = inlineEdit?.type === "rename" && inlineEdit?.path === entry.path;
  const isNewInThisDir = inlineEdit?.type !== "rename" && inlineEdit?.parentPath === entry.path && entry.is_directory;

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
    }
  };

  const handleChevronClick = async (e: React.MouseEvent) => {
    e.stopPropagation();
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
  };

  return (
    <div>
      <div
        onClick={handleClick}
        onContextMenu={(e) => onContextMenu(e, entry)}
        draggable={!isRenaming}
        onDragStart={isRenaming ? undefined : (e) => onDragStart(e, entry)}
        onDragEnd={onDragEnd}
        className={cn(
          "flex items-center gap-1.5 py-[3px] px-3 rounded cursor-pointer text-[13px] transition-colors group",
          "text-text-secondary hover:bg-bg-hover hover:text-text-primary",
          draggedPath === entry.path && "opacity-50"
        )}
        style={{ paddingLeft: `${12 + depth * 16}px` }}
        title={isRenaming ? undefined : entry.path}
      >
        {entry.is_directory ? (
          <>
            <button
              onClick={handleChevronClick}
              className="w-4 h-4 flex items-center justify-center shrink-0 hover:bg-[#222222] rounded"
            >
              {expanded ? (
                <ChevronDown className="h-3 w-3 text-text-tertiary" />
              ) : (
                <ChevronRight className="h-3 w-3 text-text-tertiary" />
              )}
            </button>
            {expanded ? (
              <FolderOpen className="h-4 w-4 shrink-0 text-[#e8a438]" />
            ) : (
              <Folder className="h-4 w-4 shrink-0 text-[#e8a438]" />
            )}
          </>
        ) : (
          <>
            <span className="w-4 shrink-0" />
            <File className="h-4 w-4 shrink-0 text-text-secondary" />
          </>
        )}
        {isRenaming ? (
          <InlineEditInput
            defaultValue={inlineEdit!.originalName}
            onConfirm={onInlineEditConfirm}
            onCancel={onInlineEditCancel}
          />
        ) : (
          <span className={cn("truncate", entry.is_directory && "font-medium text-text-primary")}>{entry.name}</span>
        )}
        {entry.is_directory && !isRenaming && (
          <div className="ml-auto opacity-0 group-hover:opacity-100 flex items-center gap-0.5 shrink-0">
            <button
              onClick={(e) => {
                e.stopPropagation();
                onNewFile(entry.path);
              }}
              className="w-5 h-5 flex items-center justify-center rounded hover:bg-[#222222] text-text-tertiary hover:text-text-primary"
              title="New File"
            >
              <FilePlus className="h-3 w-3" />
            </button>
            <button
              onClick={(e) => {
                e.stopPropagation();
                onNewDir(entry.path);
              }}
              className="w-5 h-5 flex items-center justify-center rounded hover:bg-[#222222] text-text-tertiary hover:text-text-primary"
              title="New Folder"
            >
              <FolderPlus className="h-3 w-3" />
            </button>
          </div>
        )}
      </div>
      {isNewInThisDir && expanded && (
        <div
          className="flex items-center gap-1.5 py-[3px] px-3"
          style={{ paddingLeft: `${12 + (depth + 1) * 16}px` }}
        >
          <span className="w-4 shrink-0" />
          {inlineEdit!.type === "new-dir" ? (
            <Folder className="h-4 w-4 shrink-0 text-[#e8a438] opacity-50" />
          ) : (
            <File className="h-4 w-4 shrink-0 text-text-secondary opacity-50" />
          )}
          <InlineEditInput
            defaultValue=""
            onConfirm={onInlineEditConfirm}
            onCancel={onInlineEditCancel}
          />
        </div>
      )}
      {expanded && loaded && (
        <div>
          {children.map((child) => (
            <TreeNode
              key={child.path}
              entry={child}
              onFileSelect={onFileSelect}
              depth={depth + 1}
              onContextMenu={onContextMenu}
              onDragStart={onDragStart}
              onDragEnd={onDragEnd}
              draggedPath={draggedPath}
              onNewFile={onNewFile}
              onNewDir={onNewDir}
              inlineEdit={inlineEdit}
              onInlineEditConfirm={onInlineEditConfirm}
              onInlineEditCancel={onInlineEditCancel}
              refreshKey={refreshKey}
            />
          ))}
        </div>
      )}
    </div>
  );
}