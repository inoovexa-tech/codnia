import { useState, useEffect, useRef, useCallback } from "react";
import * as monaco from "monaco-editor";
import { Sidebar } from "@/components/sidebar";
import { ActivityBar } from "@/components/activity-bar";
import { StatusBar } from "@/components/status-bar";
import { SettingsModal } from "@/components/settings-modal";
import { NewTabDropdown } from "@/components/new-tab-dropdown";
import { useEditor } from "@/hooks/use-editor";
import { useWorkspace } from "@/hooks/use-workspace";
import { useSettings } from "@/hooks/use-settings";
import { openFolderDialog } from "@/lib/tauri";
import type { AppSettings } from "@/types";

function getLanguage(filename: string): string {
  const ext = filename.split(".").pop()?.toLowerCase() || "";
  const langs: Record<string, string> = {
    rs: "rust", ts: "typescript", tsx: "typescript", js: "javascript",
    jsx: "javascript", json: "json", html: "html", css: "css",
    md: "markdown", toml: "toml", yaml: "yaml", py: "python",
  };
  return langs[ext] || "plaintext";
}

function getFileIcon(filename: string): string {
  const ext = filename.split(".").pop()?.toLowerCase() || "";
  const icons: Record<string, string> = {
    rs: "\u{1F980}", ts: "\u{1F4D8}", tsx: "\u269B", js: "\u{1F4DC}",
    json: "\u{1F4CB}", html: "\u{1F310}", css: "\u{1F3A8}",
    md: "\u{1F4DD}", toml: "\u2699",
  };
  return icons[ext] || "\u{1F4C4}";
}

export function App() {
  const { editorRef, tabs, activeTabId, initEditor, openFile, closeTab, activateTab } = useEditor();
  const {
    projects,
    activeProject,
    fileTree,
    loadProjects,
    addProject,
    setActive,
  } = useWorkspace();
  const { settings, isOpen: settingsOpen, updateSettings, openSettings, closeSettings } = useSettings();

  const [activePanel, setActivePanel] = useState<"explorer" | "api" | null>(null);
  const [cursorPosition, setCursorPosition] = useState("Ln 1, Col 1");
  const [currentLanguage, setCurrentLanguage] = useState("Plain Text");
  const editorContainerRef = useRef<HTMLDivElement>(null);
  const editorInitialized = useRef(false);

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
    }
  }, [initEditor, editorRef]);

  const handleFileSelect = useCallback(
    async (path: string) => {
      await openFile(path);
      const name = path.split("/").pop() || path;
      setCurrentLanguage(getLanguage(name).charAt(0).toUpperCase() + getLanguage(name).slice(1));
    },
    [openFile],
  );

  const handleAddProject = useCallback(async () => {
    const path = await openFolderDialog();
    if (path) {
      await addProject(path);
    }
  }, [addProject]);

  const handleExplorerClick = useCallback(() => {
    setActivePanel((prev) => (prev === "explorer" ? null : "explorer"));
  }, []);

  const handleSettingsChange = useCallback(
    (partial: Partial<AppSettings>) => {
      const merged = { ...settings, ...partial };
      updateSettings(merged);
      if (editorRef.current && partial.editor) {
        editorRef.current.updateOptions({
          minimap: { enabled: partial.editor.minimap_enabled },
          lineNumbers: partial.editor.line_numbers ? "on" : "off",
          wordWrap: partial.editor.word_wrap as "on" | "off" | "wordWrapColumn" | "bounded",
          tabSize: partial.editor.tab_size,
          insertSpaces: partial.editor.insert_spaces,
        });
      }
    },
    [settings, updateSettings, editorRef],
  );

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
          onProjectSelect={setActive}
          onAddProject={handleAddProject}
          onExplorerClick={handleExplorerClick}
          onSettingsClick={openSettings}
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
                  className={`h-[34px] px-[14px] flex items-center gap-[6px] text-[12px] border-none border-b-2 transition-colors shrink-0 rounded-t-[4px] cursor-pointer ${
                    tab.id === activeTabId
                      ? "text-white border-b-[2px] border-[#0070f3] bg-[#0c0c0c]"
                      : "text-[#888888] border-transparent hover:bg-[#222222] hover:text-white"
                  }`}
                >
                  <span className="text-[12px]">{getFileIcon(tab.name)}</span>
                  <span>{tab.name}</span>
                  {tab.isModified && (
                    <span className="w-[6px] h-[6px] rounded-full bg-[#f59e0b] ml-1" />
                  )}
                  <span
                    onClick={(e) => {
                      e.stopPropagation();
                      closeTab(tab.id);
                    }}
                    className="ml-1 w-[14px] h-[14px] flex items-center justify-center rounded opacity-50 hover:opacity-100 hover:bg-[#222222] text-[14px] leading-none"
                  >
                    ×
                  </span>
                </button>
              ))}
            </div>

            <div className="flex items-center gap-1">
              <button
                onClick={() => setActivePanel((p) => (p === "api" ? null : "api"))}
                className={`w-[28px] h-[28px] flex items-center justify-center rounded transition-colors ${
                  activePanel === "api"
                    ? "bg-[#2a2a2a] text-white"
                    : "text-[#555555] hover:bg-[#222222] hover:text-[#888888]"
                }`}
                title="REST Client"
              >
                <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M21 12a9 9 0 0 1-9 9m9-9a9 9 0 0 0-9-9m9 9H3m9 9a9 9 0 0 1-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 0 1 9-9" />
                </svg>
              </button>
              <div className="w-px h-5 bg-[#2a2a2a] mx-1" />
              <button
                onClick={handleExplorerClick}
                className={`w-[28px] h-[28px] flex items-center justify-center rounded transition-colors ${
                  activePanel === "explorer"
                    ? "bg-[#2a2a2a] text-white"
                    : "text-[#555555] hover:bg-[#222222] hover:text-[#888888]"
                }`}
                title="Explorer"
              >
                <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M3 7V17C3 18.1046 3.89543 19 5 19H19C20.1046 19 21 18.1046 21 17V9C21 7.89543 20.1046 7 19 7H12L9 3H5C3.89543 3 3 3.89543 3 5V7Z" />
                </svg>
              </button>
            </div>
          </div>

          {/* Editor */}
          <div className="flex-1 flex flex-col">
            <div ref={editorContainerRef} className="flex-1 overflow-hidden" />
          </div>
        </div>

        <ActivityBar
          activePanel={activePanel}
          isOpen={activePanel !== null}
          fileTree={fileTree}
          onFileSelect={handleFileSelect}
          onClose={() => setActivePanel(null)}
          onToggle={setActivePanel}
        />
      </div>

      <StatusBar language={currentLanguage} position={cursorPosition} />

      <SettingsModal
        open={settingsOpen}
        onOpenChange={(open) => (open ? openSettings() : closeSettings())}
        settings={settings}
        onSettingsChange={handleSettingsChange}
      />
    </div>
  );
}