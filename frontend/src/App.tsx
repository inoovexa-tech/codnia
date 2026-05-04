import { useState, useEffect, useRef, useCallback } from "react";
import { PanelRightOpen, PanelRightClose, Terminal, Code2, Circle, Layers, FileCode, FileText, FileType, FileJson, Globe, Paintbrush, Braces, File, Minus, Square, X, Search } from "lucide-react";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { Sidebar } from "@/components/sidebar";
import { ActivityBar } from "@/components/activity-bar";
import { StatusBar } from "@/components/status-bar";
import { NewTabDropdown } from "@/components/new-tab-dropdown";
import { TerminalComponent } from "@/components/terminal";
import { useEditor } from "@/hooks/use-editor";
import { useWorkspace } from "@/hooks/use-workspace";
import { createTerminal, killTerminal, showAlertDialog, openFileDialog } from "@/lib/tauri";
import { openFolderDialog } from "@/lib/tauri";
import { useSettings } from "@/hooks/use-settings";
import type { TabType, Tab } from "@/types";

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

function WindowControls() {
  if (navigator.userAgent.includes("Mac")) return null;

  const appWindow = getCurrentWindow();

  return (
    <div className="flex items-center ml-1">
      <button
        onClick={() => appWindow.minimize()}
        className="w-[46px] h-full flex items-center justify-center text-[#555555] hover:text-white hover:bg-[#1a1a1a] transition-colors"
      >
        <Minus className="h-4 w-4" />
      </button>
      <button
        onClick={() => appWindow.toggleMaximize()}
        className="w-[46px] h-full flex items-center justify-center text-[#555555] hover:text-white hover:bg-[#1a1a1a] transition-colors"
      >
        <Square className="h-3.5 w-3.5" />
      </button>
      <button
        onClick={() => appWindow.close()}
        className="w-[46px] h-full flex items-center justify-center text-[#555555] hover:text-white hover:bg-[#cc0000] transition-colors"
      >
        <X className="h-4 w-4" />
      </button>
    </div>
  );
}

export function App() {
  const { editorRef, tabs, activeTabId, initEditor, openFile, newFile, saveFile, saveFileAs, closeTab, activateTab, switchProject, markModified } = useEditor();
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

  const { settings } = useSettings();

  const projectTerminalTabsRef = useRef<Map<string, Tab[]>>(new Map());
  const projectActiveIdRef = useRef<Map<string, string | null>>(new Map());
  const [terminalTabs, setTerminalTabs] = useState<Tab[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const killedRef = useRef<Set<string>>(new Set());
  const currentProjectIdRef = useRef<string | null>(null);

  const allTabs = [...tabs, ...terminalTabs];

  useEffect(() => {
    const newProjectId = activeProject?.id ?? null;
    if (currentProjectIdRef.current === newProjectId) return;

    if (currentProjectIdRef.current) {
      projectTerminalTabsRef.current.set(
        currentProjectIdRef.current,
        terminalTabsRef.current
      );
      projectActiveIdRef.current.set(currentProjectIdRef.current, activeIdRef.current);
    }

    switchProject(newProjectId);

    const savedTerminals = newProjectId
      ? (projectTerminalTabsRef.current.get(newProjectId) ?? [])
      : [];
    setTerminalTabs(savedTerminals);

    const savedActiveId = newProjectId
      ? (projectActiveIdRef.current.get(newProjectId) ?? null)
      : null;
    setActiveId(savedActiveId);

    currentProjectIdRef.current = newProjectId;
  }, [activeProject?.id, switchProject]);

  const terminalTabsRef = useRef<Tab[]>([]);
  terminalTabsRef.current = terminalTabs;

  const activeIdRef = useRef<string | null>(null);
  activeIdRef.current = activeId;

  useEffect(() => {
    if (activeTabId) {
      setActiveId(activeTabId);
    }
  }, [activeTabId]);

  const currentTab = allTabs.find((t) => t.id === activeId);
  const isTerminalType = currentTab?.type && currentTab.type !== "file";

  const [leftSidebarExpanded, setLeftSidebarExpanded] = useState(false);
  const [rightSidebarExpanded, setRightSidebarExpanded] = useState(false);
  const [rightSidebarTab, setRightSidebarTab] = useState<"explorer" | "search">("explorer");
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

  const handleOpenSearch = useCallback(() => {
    setRightSidebarTab("search");
    setRightSidebarExpanded(true);
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
      setTerminalTabs((prev) => [...prev, terminalTab]);
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

  const allTabsRef = useRef<Tab[]>([]);
  allTabsRef.current = allTabs;

  const handleTabSelect = useCallback((id: string) => {
    setActiveId(id);
    const tab = allTabsRef.current.find((t) => t.id === id);
    if (tab && tab.type !== "terminal" && tab.type !== "opencode" && tab.type !== "claude" && tab.type !== "codex") {
      activateTab(tab.id);
    }
  }, [activateTab]);

  const handleTabClose = useCallback((id: string) => {
    const tab = allTabsRef.current.find((t) => t.id === id);
    if (tab?.terminalId) {
      killedRef.current.add(tab.terminalId);
      killTerminal(tab.terminalId).catch(() => {});
    }
    if (tab?.type && tab.type !== "file") {
      setTerminalTabs((prev) => prev.filter((t) => t.id !== id));
      const activeIdVal = activeIdRef.current;
      if (activeIdVal === id) {
        const remaining = allTabsRef.current.filter((t) => t.id !== id);
        setActiveId(remaining.length > 0 ? remaining[remaining.length - 1].id : null);
      }
    } else {
      closeTab(id);
    }
  }, [closeTab]);

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
          markModified(currentId);
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
      } else if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key === "F") {
        e.preventDefault();
        setRightSidebarTab("search");
        setRightSidebarExpanded(true);
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
        case "global_search":
          handleOpenSearch();
          break;
      }
    });
    return () => { unlisten.then((fn) => fn()); };
    }, [handleNewFile, handleOpenFile, handleSave, handleSaveAs, handleTabClose, handleLeftSidebarToggle, handleRightSidebarToggle, handleNewTerminal, handleOpenSearch, activeId]);

  const displayedTerminalTabs = allTabs.filter((t) => t.type && t.type !== "file");

  return (
    <div className="flex flex-col w-full h-full bg-[#000000] text-white font-[var(--font-sans)]">
      <div className="h-8 bg-[#000000] border-b border-[#1a1a1a] flex items-center shrink-0" data-tauri-drag-region>
        <div className="flex items-center gap-0 flex-1 overflow-x-auto" style={{ paddingLeft: 78, paddingRight: 12 }} data-tauri-drag-region>
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
              const isActive = tab.id === activeId;
              return (
              <button
                key={tab.id}
                onClick={() => handleTabSelect(tab.id)}
                className={`
                  h-[34px] flex items-center gap-[6px] text-[12px] transition-colors shrink-0 cursor-pointer
                  border border-[#222222] rounded-none
                  ${isActive
                    ? "bg-[#111111] text-white"
                    : "bg-transparent text-[#888888] hover:bg-[#0a0a0a] hover:text-white"
                  }
                `}
                style={{ paddingLeft: 14, paddingRight: 14 }}
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
                   className="ml-2 w-[20px] h-[20px] flex items-center justify-center rounded opacity-40 hover:opacity-100 hover:bg-[#222222] text-[13px] leading-none"
                >
                  ×
                </span>
              </button>
             );
           })}
        </div>

        <div className="flex items-center gap-1 shrink-0" style={{ paddingLeft: 8, paddingRight: 12, borderLeft: '1px solid #1a1a1a' }}>
          <button
            onClick={handleOpenSearch}
            className={`w-[28px] h-[28px] flex items-center justify-center rounded transition-colors ${
              rightSidebarExpanded && rightSidebarTab === "search"
                ? "text-[#0070f3]"
                : "text-white hover:text-white"
            }`}
            title="Search (Ctrl+Shift+F)"
          >
            <Search className="h-4 w-4" />
          </button>
          <button
            onClick={handleRightSidebarToggle}
            className={`w-[28px] h-[28px] flex items-center justify-center rounded transition-colors ${
              rightSidebarExpanded
                ? "text-[#0070f3]"
                : "text-white hover:text-white"
            }`}
            title={rightSidebarExpanded ? "Collapse Panel" : "Expand Panel"}
          >
            {rightSidebarExpanded ? <PanelRightClose className="h-4 w-4" /> : <PanelRightOpen className="h-4 w-4" />}
          </button>
        </div>

        <WindowControls />
      </div>

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
          onProjectRemoved={loadProjects}
          onProjectRenamed={loadProjects}
        />

        <div className="flex-1 flex flex-col min-w-0 bg-[#000000] relative">
          <div className="flex-1 flex flex-col relative">
            <div
              ref={editorContainerRef}
              className="flex-1 overflow-hidden"
              style={{ display: (!currentTab?.type || currentTab.type === "file") && allTabs.length > 0 && activeId ? "block" : "none" }}
            />

            {allTabs.length === 0 || !activeId ? (
              <div className="flex-1 flex items-center justify-center bg-[#000000]">
                <div className="flex flex-col items-center gap-3 text-[#555555]">
                  <svg className="w-16 h-16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1" opacity="0.3">
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                    <polyline points="14 2 14 8 20 8" />
                  </svg>
                  <span className="text-[13px]">Open a file to start editing</span>
                </div>
              </div>
            ) : null}

            {displayedTerminalTabs.map((tab) => (
              tab.terminalId && !killedRef.current.has(tab.terminalId) ? (
                <div
                  key={tab.id}
                  className="flex-1 overflow-hidden bg-[#000000]"
                  style={{ display: tab.id === activeId ? "flex" : "none" }}
                >
                  <TerminalComponent terminalId={tab.terminalId} visible={tab.id === activeId} fontSize={settings.terminal.font_size} scrollback={settings.terminal.scrollback} />
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
            activeProjectPath={activeProject?.path}
            activeTab={rightSidebarTab}
            onTabChange={setRightSidebarTab}
          />
        )}
      </div>

      {!isTerminalType && activeId && allTabs.length > 0 && (
        <StatusBar language={currentLanguage} position={cursorPosition} />
      )}
    </div>
  );
}