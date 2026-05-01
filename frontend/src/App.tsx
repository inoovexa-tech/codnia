import { useState, useEffect, useRef, useCallback } from "react";
import * as monaco from "monaco-editor";
import { PanelRightOpen, PanelRightClose } from "lucide-react";
import { invoke } from "@tauri-apps/api/core";
import { Sidebar } from "@/components/sidebar";
import { ActivityBar } from "@/components/activity-bar";
import { StatusBar } from "@/components/status-bar";
import { NewTabDropdown } from "@/components/new-tab-dropdown";
import { useEditor } from "@/hooks/use-editor";
import { useWorkspace } from "@/hooks/use-workspace";
import { openFolderDialog } from "@/lib/tauri";

export function App() {
  const { editorRef, tabs, activeTabId, initEditor, openFile, closeTab, activateTab } = useEditor();
  const {
    projects,
    activeProject,
    fileTree,
    branches,
    loadProjects,
    addProject,
    setActive,
  } = useWorkspace();

  const [rightSidebarExpanded, setRightSidebarExpanded] = useState(false);
  const [cursorPosition, setCursorPosition] = useState("Ln 1, Col 1");
  const [currentLanguage, setCurrentLanguage] = useState("Plain Text");
  const editorContainerRef = useRef<HTMLDivElement>(null);
  const editorInitialized = useRef(false);

  useEffect(() => {
    loadProjects();
  }, [loadProjects]);

  useEffect(() => {
    if (tabs.length > 0 && activeTabId && editorContainerRef.current && !editorInitialized.current) {
      initEditor(editorContainerRef.current);
      editorInitialized.current = true;

      editorRef.current?.onDidChangeCursorPosition((e) => {
        setCursorPosition(`Ln ${e.position.lineNumber}, Col ${e.position.column}`);
      });
    }
  }, [initEditor, editorRef, tabs.length, activeTabId]);

  useEffect(() => {
    if (editorInitialized.current && editorRef.current && editorContainerRef.current) {
      if (tabs.length === 0 || !activeTabId) {
        const model = editorRef.current.getModel();
        if (model) {
          editorRef.current.setValue("");
          monaco.editor.setModelLanguage(model, "plaintext");
        }
      } else {
        editorRef.current.layout();
      }
    }
  }, [editorRef, tabs.length, activeTabId]);

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
    if (editorRef.current) {
      editorRef.current.setValue("");
      const model = editorRef.current.getModel();
      if (model) {
        monaco.editor.setModelLanguage(model, "plaintext");
      }
    }
  }, [editorRef]);

  const handleNewTerminal = useCallback(() => {
    console.log("Opening terminal...");
  }, []);

  return (
    <div className="flex flex-col w-full h-full bg-[#0c0c0c] text-white font-[var(--font-sans)]">
      <div className="flex flex-1 overflow-hidden relative">
        <Sidebar
          projects={projects}
          activeProjectId={activeProject?.id}
          branches={branches}
          onProjectSelect={setActive}
          onAddProject={handleAddProject}
          onSettingsClick={openSettingsWindow}
        />

        <div className="flex-1 flex flex-col min-w-0 bg-[#0c0c0c] relative">
          {/* Tabs bar */}
          <div className="h-10 bg-[#111111] border-b border-[#2a2a2a] flex items-center px-3 gap-2 shrink-0">
            <div className="flex items-center gap-[2px] flex-1 overflow-x-auto">
              <NewTabDropdown
                onTerminal={handleNewTerminal}
                onOpenCode={() => console.log("OpenCode")}
                onClaudeCode={() => console.log("Claude Code")}
                onCodex={() => console.log("Codex")}
                onNewFile={handleNewFile}
              />
               {tabs.map((tab) => (
                <button
                  key={tab.id}
                  onClick={() => activateTab(tab.id)}
                  className={`h-[34px] px-[14px] flex items-center gap-[6px] text-[12px] transition-colors shrink-0 cursor-pointer border-b-[3px] ${
                    tab.id === activeTabId
                      ? "text-white border-[#0070f3] bg-[#0c0c0c]"
                      : "text-[#888888] border-transparent hover:bg-[#222222] hover:text-white"
                  }`}
                >
                  <span className="text-[12px]">📄</span>
                  <span>{tab.name}</span>
                  {tab.isModified && (
                    <span className="w-[6px] h-[6px] rounded-full bg-[#f59e0b] ml-1" />
                  )}
                   <span
                     onClick={(e) => {
                       e.stopPropagation();
                       closeTab(tab.id);
                     }}
                     className="ml-2 w-[20px] h-[20px] flex items-center justify-center rounded opacity-40 hover:opacity-100 hover:bg-[#333333] text-[13px] leading-none"
                   >
                     ×
                   </span>
                </button>
              ))}
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

          {/* Editor */}
          <div className="flex-1 flex flex-col relative">
            {tabs.length === 0 || !activeTabId ? (
              <div className="flex-1 flex items-center justify-center bg-[#0c0c0c]">
                <div className="flex flex-col items-center gap-3 text-[#555555]">
                  <svg className="w-16 h-16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1" opacity="0.3">
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                    <polyline points="14 2 14 8 20 8" />
                  </svg>
                  <span className="text-[13px]">Open a file to start editing</span>
                </div>
              </div>
            ) : (
              <div ref={editorContainerRef} className="flex-1 overflow-hidden" />
            )}
          </div>
        </div>

        {rightSidebarExpanded && (
          <ActivityBar
            fileTree={fileTree}
            onFileSelect={handleFileSelect}
            onClose={handleRightSidebarToggle}
          />
        )}
      </div>

      <StatusBar language={currentLanguage} position={cursorPosition} />
    </div>
  );
}
