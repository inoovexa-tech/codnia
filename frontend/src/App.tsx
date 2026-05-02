import { useState, useEffect, useRef, useCallback } from "react";
import { PanelRightOpen, PanelRightClose, Terminal, Code2, Circle, Layers, FileCode, FileText, FileType, FileJson, Globe, Paintbrush, Braces, File } from "lucide-react";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { Sidebar } from "@/components/sidebar";
import { ActivityBar } from "@/components/activity-bar";
import { StatusBar } from "@/components/status-bar";
import { NewTabDropdown } from "@/components/new-tab-dropdown";
import { TerminalComponent } from "@/components/terminal";
import { useEditor } from "@/hooks/use-editor";
import { useWorkspace } from "@/hooks/use-workspace";
import { createTerminal, killTerminal, showAlertDialog, openFileDialog } from "@/lib/tauri";
import { openFolderDialog } from "@/lib/tauri";
import type { TabType } from "@/types";

const COMMAND_LABELS: Record<string, string> = {
  opencode: "OpenCode",
  claude: "Claude Code",
  codex: "Codex",
};

const TAB_TYPE_ICONS: Record<string, { icon: React.ReactNode; color: string }> = {
  terminal: { icon: <Terminal className="h-3.5 w-3.5" />, color: "text-[#10b981]" },
  opencode: { icon: <Code2 className="h-3.5 w-3.5" />, color: "text-[#0070f3]" },
  claude: { icon: <Circle className="h-3.5 w-3.5" />, color: "text-[#d97706]" },
  codex: { icon: <Layers className="h-3.5 w-3.5" />, color: "text-[#8b5cf6]" },
};

const TAB_TYPE_COMMANDS: Record<string, string> = {
  opencode: "opencode",
  claude: "claude",
  codex: "codex",
};

const FILE_ICON_MAP: Record<string, React.ReactNode> = {
  rs: <Braces className="h-3.5 w-3.5 text-[#dea584]" />,
  ts: <FileCode className="h-3.5 w-3.5 text-[#3178c6]" />,
  tsx: <FileCode className="h-3.5 w-3.5 text-[#3178c6]" />,
  js: <FileCode className="h-3.5 w-3.5 text-[#f7df1e]" />,
  jsx: <FileCode className="h-3.5 w-3.5 text-[#f7df1e]" />,
  json: <FileJson className="h-3.5 w-3.5 text-[#f7df1e]" />,
  html: <Globe className="h-3.5 w-3.5 text-[#e34c26]" />,
  css: <Paintbrush className="h-3.5 w-3.5 text-[#264de4]" />,
  scss: <Paintbrush className="h-3.5 w-3.5 text-[#cf649a]" />,
  md: <FileText className="h-3.5 w-3.5 text-[#8b949e]" />,
  toml: <FileType className="h-3.5 w-3.5 text-[#8b949e]" />,
  yaml: <FileType className="h-3.5 w-3.5 text-[#8b949e]" />,
  yml: <FileType className="h-3.5 w-3.5 text-[#8b949e]" />,
  sh: <Terminal className="h-3.5 w-3.5 text-[#4eaa25]" />,
  py: <FileCode className="h-3.5 w-3.5 text-[#3776ab]" />,
  go: <FileCode className="h-3.5 w-3.5 text-[#00add8]" />,
};

function getFileIcon(filename: string): React.ReactNode {
  const ext = filename.split(".").pop()?.toLowerCase() || "";
  return FILE_ICON_MAP[ext] || <File className="h-3.5 w-3.5 text-[#8b949e]" />;
}

export function App() {
  const { editorRef, tabs, activeTabId, initEditor, openFile, newFile, saveFile, saveFileAs, closeTab, activateTab } = useEditor();
  const {
    projects,
    activeProject,
    fileTree,
    branches: _branches,
    loadProjects,
    addProject,
    setActive,
    refreshFileTree,
  } = useWorkspace();

  const [allTabs, setAllTabs] = useState<import("@/types").Tab[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const killedRef = useRef<Set<string>>(new Set());

  useEffect(() => {
    setAllTabs((prev) => {
      const terminalTabs = prev.filter((t) => t.type && t.type !== "file");
      return [...tabs, ...terminalTabs];
    });
  }, [tabs]);

  useEffect(() => {
    if (activeTabId) {
      setActiveId(activeTabId);
    }
  }, [activeTabId]);

  const currentTab = allTabs.find((t) => t.id === activeId);
  const isTerminalType = currentTab?.type && currentTab.type !== "file";

  const [leftSidebarExpanded, setLeftSidebarExpanded] = useState(false);
  const [rightSidebarExpanded, setRightSidebarExpanded] = useState(false);
  const [cursorPosition, setCursorPosition] = useState("Ln 1, Col 1");
  const [currentLanguage, setCurrentLanguage] = useState("Plain Text");
  const editorContainerRef = useRef<HTMLDivElement>(null);
  const editorInitialized = useRef(false);

  const handleFileSelect = useCallback(
    async (path: string) => {
      await openFile(path);
      const name = path.split("/").pop() || path;
      setCurrentLanguage(
        name.split(".").pop()?.toLowerCase() === "rs" ? "Rust"
          : name.split(".").pop()?.toLowerCase() === "ts" ? "TypeScript"
          : name.split(".").pop()?.toLowerCase() === "tsx" ? "TypeScript"
          : name.split(".").pop()?.toLowerCase() === "js" ? "JavaScript"
          : name.split(".").pop()?.toLowerCase() === "json" ? "JSON"
          : name.split(".").pop()?.toLowerCase() === "html" ? "HTML"
          : name.split(".").pop()?.toLowerCase() === "css" ? "CSS"
          : name.split(".").pop()?.toLowerCase() === "md" ? "Markdown"
          : "Plain Text"
      );
    },
    [openFile],
  );

  const handleAddProject = useCallback(async () => {
    const path = await openFolderDialog();
    if (path) {
      await addProject(path);
    }
  }, [addProject]);

  const handleLeftSidebarToggle = useCallback(() => {
    setLeftSidebarExpanded((prev) => !prev);
  }, []);

  const handleRightSidebarToggle = useCallback(() => {
    setRightSidebarExpanded((prev) => !prev);
  }, []);

  const openSettingsWindow = useCallback(async () => {
    try {
      await invoke("open_settings_window");
    } catch (e) {
      console.error("Failed to open settings window:", e);
    }
  }, []);

  const handleNewFile = useCallback(() => {
    newFile();
  }, [newFile]);

  const handleOpenFile = useCallback(async () => {
    const path = await openFileDialog();
    if (path) {
      await handleFileSelect(path);
    }
  }, [handleFileSelect]);

  const handleSave = useCallback(() => {
    saveFile(activeProject?.path);
  }, [saveFile, activeProject?.path]);

  const handleSaveAs = useCallback(() => {
    saveFileAs(activeProject?.path);
  }, [saveFileAs, activeProject?.path]);

  const createTerminalTab = useCallback(async (type: TabType, commandOverride?: string) => {
    try {
      const cwd = activeProject?.path;
      const command = commandOverride ?? (type !== "terminal" && type !== "file" ? TAB_TYPE_COMMANDS[type] : undefined);
      const instance = await createTerminal(cwd ? { cwd, command } : command ? { command } : undefined);
      const terminalTab = {
        id: `terminal-${instance.id}`,
        path: instance.cwd,
        name: instance.name,
        isModified: false,
        language: "",
        type,
        terminalId: instance.id,
      };
      setAllTabs((prev) => [...prev, terminalTab]);
      setActiveId(terminalTab.id);
    } catch (e: unknown) {
      if (commandOverride && COMMAND_LABELS[commandOverride]) {
        const label = COMMAND_LABELS[commandOverride];
        await showAlertDialog(
          `${label} not found`,
          `${label} is not installed on your system.\n\nPlease install it first to use this feature.`
        );
      } else {
        console.error("Failed to create terminal:", e);
      }
    }
  }, [activeProject?.path]);

  const handleNewTerminal = useCallback(() => createTerminalTab("terminal"), [createTerminalTab]);
  const handleOpenCode = useCallback(() => createTerminalTab("opencode", "opencode"), [createTerminalTab]);
  const handleClaudeCode = useCallback(() => createTerminalTab("claude", "claude"), [createTerminalTab]);
  const handleCodex = useCallback(() => createTerminalTab("codex", "codex"), [createTerminalTab]);

  const handleTabSelect = useCallback((id: string) => {
    setActiveId(id);
    const tab = allTabs.find((t) => t.id === id);
    if (tab && tab.type !== "terminal" && tab.type !== "opencode" && tab.type !== "claude" && tab.type !== "codex") {
      activateTab(tab.id);
    }
  }, [allTabs, activateTab]);

  const handleTabClose = useCallback((id: string) => {
    const tab = allTabs.find((t) => t.id === id);
    if (tab?.terminalId) {
      killedRef.current.add(tab.terminalId);
      killTerminal(tab.terminalId).catch(() => {});
    }
    if (tab?.type && tab.type !== "file") {
      setAllTabs((prev) => prev.filter((t) => t.id !== id));
      if (activeId === id) {
        const remaining = allTabs.filter((t) => t.id !== id);
        setActiveId(remaining.length > 0 ? remaining[remaining.length - 1].id : null);
      }
    } else {
      closeTab(id);
    }
  }, [allTabs, activeId, closeTab]);

  useEffect(() => {
    loadProjects();
  }, [loadProjects]);

  useEffect(() => {
    if (editorContainerRef.current && !editorInitialized.current) {
      initEditor(editorContainerRef.current);
      editorInitialized.current = true;

      editorRef.current?.onDidChangeCursorPosition((e) => {
        setCursorPosition(`Ln ${e.position.lineNumber}, Col ${e.position.column}`);
      });

      editorRef.current?.onDidChangeModelContent(() => {
        const currentId = activeTabId;
        if (currentId) {
          setAllTabs((prev) => {
            const t = prev.find((tab) => tab.id === currentId);
            if (t && !t.isModified && (!t.type || t.type === "file")) {
              return prev.map((tab) => tab.id === currentId ? { ...tab, isModified: true } : tab);
            }
            return prev;
          });
        }
      });
    }
  }, [initEditor, editorRef, activeTabId]);

  useEffect(() => {
    if (editorInitialized.current && editorRef.current) {
      editorRef.current.layout();
    }
  }, [editorRef, activeId]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key === "S") {
        e.preventDefault();
        saveFileAs(activeProject?.path);
      } else if ((e.metaKey || e.ctrlKey) && e.key === "s") {
        e.preventDefault();
        saveFile(activeProject?.path);
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [saveFile, saveFileAs, activeProject?.path]);

  useEffect(() => {
    const unlisten = listen<string>("menu-event", (event) => {
      switch (event.payload) {
        case "new_file":
          handleNewFile();
          break;
        case "open_file":
          handleOpenFile();
          break;
        case "save":
          handleSave();
          break;
        case "save_as":
          handleSaveAs();
          break;
        case "close_tab":
          if (activeId) handleTabClose(activeId);
          break;
        case "toggle_sidebar":
          handleRightSidebarToggle();
          break;
        case "toggle_terminal":
          handleNewTerminal();
          break;
      }
    });
    return () => { unlisten.then((fn) => fn()); };
    }, [handleNewFile, handleOpenFile, handleSave, handleSaveAs, handleTabClose, handleLeftSidebarToggle, handleRightSidebarToggle, handleNewTerminal, activeId]);

  const terminalTabs = allTabs.filter((t) => t.type && t.type !== "file");

  return (
    <div className="flex flex-col w-full h-full bg-[#0c0c0c] text-white font-[var(--font-sans)]">
      <div className="flex flex-1 overflow-hidden relative">
        <Sidebar
          projects={projects}
          activeProjectId={activeProject?.id}
          branches={_branches}
          expanded={leftSidebarExpanded}
          onToggleExpand={handleLeftSidebarToggle}
          onProjectSelect={setActive}
          onAddProject={handleAddProject}
          onSettingsClick={openSettingsWindow}
        />

        <div className="flex-1 flex flex-col min-w-0 bg-[#0c0c0c] relative">
          <div className="h-10 bg-[#111111] border-b border-[#2a2a2a] flex items-center px-3 gap-2 shrink-0">
            <div className="flex items-center gap-[2px] flex-1 overflow-x-auto">
              <NewTabDropdown
                onTerminal={handleNewTerminal}
                onOpenCode={handleOpenCode}
                onClaudeCode={handleClaudeCode}
                onCodex={handleCodex}
                onNewFile={handleNewFile}
              />
               {allTabs.map((tab) => {
                 const typeInfo = tab.type ? TAB_TYPE_ICONS[tab.type] : undefined;
                 const displayName = tab.isModified && !tab.type ? `${tab.name} ●` : tab.name;
                 return (
                <button
                  key={tab.id}
                  onClick={() => handleTabSelect(tab.id)}
                  className={`h-[34px] px-[14px] flex items-center gap-[6px] text-[12px] transition-colors shrink-0 cursor-pointer border-b-[3px] ${
                    tab.id === activeId
                      ? "text-white border-[#0070f3] bg-[#0c0c0c]"
                      : "text-[#888888] border-transparent hover:bg-[#222222] hover:text-white"
                  }`}
                >
                  {typeInfo ? (
                    <span className={typeInfo.color}>{typeInfo.icon}</span>
                  ) : (
                    getFileIcon(tab.name)
                  )}
                  <span>{displayName}</span>
                   <span
                     onClick={(e) => {
                       e.stopPropagation();
                       handleTabClose(tab.id);
                     }}
                     className="ml-2 w-[20px] h-[20px] flex items-center justify-center rounded opacity-40 hover:opacity-100 hover:bg-[#333333] text-[13px] leading-none"
                   >
                     ×
                   </span>
                </button>
               );
              })}
            </div>

            <div className="flex items-center gap-1">
              <button
                onClick={handleRightSidebarToggle}
                className={`w-[28px] h-[28px] flex items-center justify-center rounded transition-colors ${
                  rightSidebarExpanded
                    ? "bg-[#2a2a2a] text-white"
                    : "text-[#555555] hover:bg-[#222222] hover:text-[#888888]"
                }`}
                title={rightSidebarExpanded ? "Collapse Panel" : "Expand Panel"}
              >
                {rightSidebarExpanded ? <PanelRightClose className="h-4 w-4" /> : <PanelRightOpen className="h-4 w-4" />}
              </button>
            </div>
          </div>

          <div className="flex-1 flex flex-col relative">
            <div
              ref={editorContainerRef}
              className="flex-1 overflow-hidden"
              style={{ display: (!currentTab?.type || currentTab.type === "file") && allTabs.length > 0 && activeId ? "block" : "none" }}
            />

            {allTabs.length === 0 || !activeId ? (
              <div className="flex-1 flex items-center justify-center bg-[#0c0c0c]">
                <div className="flex flex-col items-center gap-3 text-[#555555]">
                  <svg className="w-16 h-16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1" opacity="0.3">
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                    <polyline points="14 2 14 8 20 8" />
                  </svg>
                  <span className="text-[13px]">Open a file to start editing</span>
                </div>
              </div>
            ) : null}

            {terminalTabs.map((tab) => (
              tab.terminalId && !killedRef.current.has(tab.terminalId) ? (
                <div
                  key={tab.id}
                  className="flex-1 overflow-hidden bg-[#0c0c0c]"
                  style={{ display: tab.id === activeId ? "flex" : "none" }}
                >
                  <TerminalComponent terminalId={tab.terminalId} visible={tab.id === activeId} />
                </div>
              ) : null
            ))}
          </div>
        </div>

        {rightSidebarExpanded && (
          <ActivityBar
            fileTree={fileTree}
            onFileSelect={handleFileSelect}
            onClose={handleRightSidebarToggle}
            onRefresh={refreshFileTree}
          />
        )}
      </div>

      <StatusBar language={isTerminalType ? "Terminal" : currentLanguage} position={cursorPosition} />
    </div>
  );
}