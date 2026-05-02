import { useState, useCallback, useRef, useEffect } from "react";
import * as monaco from "monaco-editor";
import { readFile, writeFile, saveFileDialog } from "@/lib/tauri";
import type { Tab } from "@/types";

function getLanguage(filename: string): string {
  const ext = filename.split(".").pop()?.toLowerCase() || "";
  const langs: Record<string, string> = {
    rs: "rust", ts: "typescript", tsx: "typescript", js: "javascript",
    jsx: "javascript", json: "json", html: "html", css: "css",
    scss: "scss", less: "less", md: "markdown", toml: "toml",
    yaml: "yaml", yml: "yaml", sh: "shell", bash: "shell",
    py: "python", rb: "ruby", go: "go", java: "java",
    c: "c", cpp: "cpp", h: "c", hpp: "cpp", cs: "csharp",
    swift: "swift", kt: "kotlin",
  };
  return langs[ext] || "plaintext";
}

interface ProjectTabState {
  tabs: Tab[];
  activeTabId: string | null;
}

export function useEditor() {
  const editorRef = useRef<monaco.editor.IStandaloneCodeEditor | null>(null);
  const projectTabsRef = useRef<Map<string, ProjectTabState>>(new Map());
  const currentProjectIdRef = useRef<string | null>(null);
  const [tabs, setTabs] = useState<Tab[]>([]);
  const [activeTabId, setActiveTabId] = useState<string | null>(null);
  const tabsRef = useRef<Tab[]>([]);
  const pendingFileRef = useRef<Tab | null>(null);

  useEffect(() => {
    tabsRef.current = tabs;
    if (currentProjectIdRef.current) {
      const state = projectTabsRef.current.get(currentProjectIdRef.current);
      if (state) {
        state.tabs = tabs;
        state.activeTabId = activeTabId;
      }
    }
  }, [tabs, activeTabId]);

  const switchProject = useCallback((projectId: string | null) => {
    if (currentProjectIdRef.current) {
      projectTabsRef.current.set(currentProjectIdRef.current, {
        tabs: tabsRef.current,
        activeTabId: activeTabId ? activeTabId : null,
      });
    }

    currentProjectIdRef.current = projectId;

    if (projectId && projectTabsRef.current.has(projectId)) {
      const state = projectTabsRef.current.get(projectId)!;
      setTabs(state.tabs);
      setActiveTabId(state.activeTabId);
      tabsRef.current = state.tabs;
    } else {
      setTabs([]);
      setActiveTabId(null);
      tabsRef.current = [];
    }
  }, [activeTabId]);

  const initEditor = useCallback((container: HTMLElement) => {
    if (editorRef.current) return;

    const saved = localStorage.getItem("codnia-settings");
    const settings = saved ? JSON.parse(saved) : { minimap: false };

    monaco.editor.defineTheme("codnia-dark", {
      base: "vs-dark",
      inherit: false,
      rules: [
        { token: "", foreground: "D4D4D4", background: "000000" },
        { token: "comment", foreground: "6A9955" },
        { token: "keyword", foreground: "569CD6" },
        { token: "string", foreground: "CE9178" },
        { token: "number", foreground: "B5CEA8" },
        { token: "regexp", foreground: "D16969" },
        { token: "type", foreground: "4EC9B0" },
        { token: "class", foreground: "4EC9B0" },
        { token: "function", foreground: "DCDCAA" },
        { token: "variable", foreground: "9CDCFE" },
        { token: "variable.predefined", foreground: "4FC1FF" },
        { token: "constant", foreground: "4FC1FF" },
        { token: "tag", foreground: "569CD6" },
        { token: "attribute.name", foreground: "9CDCFE" },
        { token: "attribute.value", foreground: "CE9178" },
        { token: "delimiter", foreground: "D4D4D4" },
        { token: "delimiter.bracket", foreground: "D4D4D4" },
        { token: "operator", foreground: "D4D4D4" },
        { token: "meta.tag", foreground: "569CD6" },
      ],
      colors: {
        "editor.background": "#000000",
        "editor.foreground": "#D4D4D4",
        "editor.lineHighlightBackground": "#111111",
        "editor.selectionBackground": "#264f78",
        "editor.inactiveSelectionBackground": "#1a1a1a",
        "editorCursor.foreground": "#ffffff",
        "editorWhitespace.foreground": "#333333",
        "editorIndentGuide.background": "#1a1a1a",
        "editorIndentGuide.activeBackground": "#333333",
        "editorLineNumber.foreground": "#444444",
        "editorLineNumber.activeForeground": "#888888",
        "editor.selectionHighlightBackground": "#264f7833",
        "editorBracketMatch.background": "#1a1a1a",
        "editorBracketMatch.border": "#333333",
        "editorOverviewRuler.border": "#000000",
        "editorGutter.background": "#000000",
        "scrollbarSlider.background": "#1a1a1a",
        "scrollbarSlider.hoverBackground": "#333333",
        "scrollbarSlider.activeBackground": "#444444",
        "minimap.background": "#000000",
        "editorWidget.background": "#000000",
        "editorWidget.border": "#1a1a1a",
        "editorSuggestWidget.background": "#000000",
        "editorSuggestWidget.border": "#1a1a1a",
        "editorSuggestWidget.selectedBackground": "#1a1a1a",
        "editor.findMatchBackground": "#264f7833",
        "editor.findMatchHighlightBackground": "#264f7800",
        "editorOverviewRuler.background": "#000000",
        "editorPane.background": "#000000",
        "editorGroupHeader.tabsBackground": "#000000",
        "editorLineNumber.background": "#000000",
        "editorMarkerNavigation.background": "#000000",
        "editorMarkerNavigationError.background": "#000000",
        "editorMarkerNavigationWarning.background": "#000000",
        "input.background": "#111111",
        "input.border": "#1a1a1a",
        "peekViewEditor.background": "#000000",
        "peekViewResult.background": "#000000",
        "peekViewResult.selectionBackground": "#1a1a1a",
      },
    });

    const editor = monaco.editor.create(container, {
      value: "",
      language: "plaintext",
      theme: "codnia-dark",
      fontSize: 13,
      fontFamily: "'SF Mono', 'Fira Code', Consolas, monospace",
      minimap: { enabled: settings.minimap },
      automaticLayout: true,
      scrollBeyondLastLine: false,
      lineNumbers: "on",
      renderWhitespace: "selection",
      tabSize: 4,
      insertSpaces: true,
      mouseWheelZoom: false,
    });

    editorRef.current = editor;

    if (pendingFileRef.current) {
      const tab = pendingFileRef.current;
      const uri = monaco.Uri.file(tab.path);
      const model = monaco.editor.getModel(uri);
      if (model) {
        editor.setModel(model);
      }
      pendingFileRef.current = null;
    }
  }, []);

  const openFile = useCallback(async (path: string) => {
    const currentTabs = tabsRef.current;
    const existing = currentTabs.find((t) => t.path === path);
    if (existing) {
      setActiveTabId(existing.id);
      if (editorRef.current) {
        const uri = monaco.Uri.file(path);
        const model = monaco.editor.getModel(uri);
        if (model && editorRef.current.getModel() !== model) {
          editorRef.current.setModel(model);
        }
      }
      return;
    }

    const name = path.split("/").pop() || path;
    const language = getLanguage(name);
    const content = await readFile(path);

    const uri = monaco.Uri.file(path);
    let model = monaco.editor.getModel(uri);
    if (!model) {
      model = monaco.editor.createModel(content, language, uri);
    } else {
      model.setValue(content);
    }

    if (editorRef.current) {
      editorRef.current.setModel(model);
    }

    const tab: Tab = {
      id: `file-${Date.now()}`,
      path,
      name,
      isModified: false,
      language,
    };

    setTabs((prev) => [...prev, tab]);
    setActiveTabId(tab.id);

    if (!editorRef.current) {
      pendingFileRef.current = tab;
    }
  }, []);

  const newFile = useCallback(() => {
    const id = `untitled-${Date.now()}`;
    const tab: Tab = {
      id,
      path: "",
      name: "Untitled",
      isModified: false,
      language: "plaintext",
    };

    if (editorRef.current) {
      const uri = monaco.Uri.parse(`inmemory://${id}`);
      const model = monaco.editor.createModel("", "plaintext", uri);
      editorRef.current.setModel(model);
    }

    setTabs((prev) => [...prev, tab]);
    setActiveTabId(id);
  }, []);

  const saveFile = useCallback(async (projectPath?: string | null) => {
    if (!activeTabId || !editorRef.current) return false;

    const currentTabs = tabsRef.current;
    const tab = currentTabs.find((t) => t.id === activeTabId);
    if (!tab) return false;

    const model = editorRef.current.getModel();
    if (!model) return false;

    const content = model.getValue();

    let savePath = tab.path;

    if (!savePath) {
      const defaultDir = projectPath || "";
      const defaultPath = defaultDir ? `${defaultDir}/untitled` : undefined;
      const chosen = await saveFileDialog(defaultPath);
      if (!chosen) return false;
      savePath = chosen;
    }

    try {
      await writeFile(savePath, content);
    } catch {
      return false;
    }

    const name = savePath.split("/").pop() || savePath;
    const language = getLanguage(name);

    if (!tab.path) {
      const newUri = monaco.Uri.file(savePath);
      const newModel = monaco.editor.createModel(content, language, newUri);
      editorRef.current.setModel(newModel);

      if (model.uri.scheme === "inmemory") {
        model.dispose();
      }

      monaco.editor.setModelLanguage(newModel, language);
    } else {
      monaco.editor.setModelLanguage(model, language);
    }

    setTabs((prev) =>
      prev.map((t) =>
        t.id === activeTabId
          ? { ...t, path: savePath, name, isModified: false, language }
          : t
      )
    );

    return true;
  }, [activeTabId]);

  const saveFileAs = useCallback(async (projectPath?: string | null) => {
    if (!activeTabId || !editorRef.current) return false;

    const currentTabs = tabsRef.current;
    const tab = currentTabs.find((t) => t.id === activeTabId);
    if (!tab) return false;

    const model = editorRef.current.getModel();
    if (!model) return false;

    const content = model.getValue();

    const defaultDir = projectPath || tab.path ? tab.path.split("/").slice(0, -1).join("/") : "";
    const defaultPath = defaultDir ? `${defaultDir}/${tab.name}` : undefined;
    const chosen = await saveFileDialog(defaultPath);
    if (!chosen) return false;

    try {
      await writeFile(chosen, content);
    } catch {
      return false;
    }

    const name = chosen.split("/").pop() || chosen;
    const language = getLanguage(name);

    const newUri = monaco.Uri.file(chosen);
    const newModel = monaco.editor.createModel(content, language, newUri);
    editorRef.current.setModel(newModel);

    if (model.uri.scheme === "inmemory") {
      model.dispose();
    }

    monaco.editor.setModelLanguage(newModel, language);

    setTabs((prev) =>
      prev.map((t) =>
        t.id === activeTabId
          ? { ...t, path: chosen, name, isModified: false, language }
          : t
      )
    );

    return true;
  }, [activeTabId]);

  const closeTab = useCallback(
    (tabId: string) => {
      setTabs((prev) => {
        const closingTab = prev.find((t) => t.id === tabId);
        const idx = prev.findIndex((t) => t.id === tabId);
        const next = prev.filter((t) => t.id !== tabId);

        if (closingTab && editorRef.current) {
          if (activeTabId === tabId) {
            const newActive = next[Math.max(0, idx - 1)]?.id || null;
            setActiveTabId(newActive);

            if (newActive) {
              const nextTab = next.find((t) => t.id === newActive);
              if (nextTab) {
                if (nextTab.path) {
                  const uri = monaco.Uri.file(nextTab.path);
                  const existingModel = monaco.editor.getModel(uri);
                  if (existingModel) {
                    editorRef.current.setModel(existingModel);
                  } else {
                    readFile(nextTab.path).then((content) => {
                      if (editorRef.current) {
                        const newModel = monaco.editor.createModel(content, nextTab.language, uri);
                        editorRef.current.setModel(newModel);
                      }
                    });
                  }
                } else {
                  const uri = monaco.Uri.parse(`inmemory://${nextTab.id}`);
                  const existingModel = monaco.editor.getModel(uri);
                  if (existingModel) {
                    editorRef.current.setModel(existingModel);
                  } else {
                    const newModel = monaco.editor.createModel("", "plaintext", uri);
                    editorRef.current.setModel(newModel);
                  }
                }
              }
            } else {
              editorRef.current.setValue("");
              const emptyModel = editorRef.current.getModel();
              if (emptyModel) {
                monaco.editor.setModelLanguage(emptyModel, "plaintext");
              }
            }
          }
        }

        return next;
      });
    },
    [activeTabId],
  );

  const activateTab = useCallback(
    async (tabId: string) => {
      const currentTabs = tabsRef.current;
      const tab = currentTabs.find((t) => t.id === tabId);
      if (!tab || !editorRef.current) return;

      setActiveTabId(tabId);

      if (tab.path) {
        const uri = monaco.Uri.file(tab.path);
        const existingModel = monaco.editor.getModel(uri);
        if (existingModel) {
          editorRef.current.setModel(existingModel);
        } else {
          const content = await readFile(tab.path);
          const model = monaco.editor.createModel(content, tab.language, uri);
          editorRef.current.setModel(model);
        }
      } else {
        const uri = monaco.Uri.parse(`inmemory://${tab.id}`);
        let existingModel = monaco.editor.getModel(uri);
        if (!existingModel) {
          existingModel = monaco.editor.createModel("", "plaintext", uri);
        }
        editorRef.current.setModel(existingModel);
      }
    },
    [],
  );

  const markModified = useCallback((tabId: string) => {
    setTabs((prev) => {
      const t = prev.find((tab) => tab.id === tabId);
      if (t && !t.isModified) {
        return prev.map((tab) => tab.id === tabId ? { ...tab, isModified: true } : tab);
      }
      return prev;
    });
  }, []);

  return {
    editorRef,
    tabs,
    activeTabId,
    initEditor,
    openFile,
    newFile,
    saveFile,
    saveFileAs,
    closeTab,
    activateTab,
    switchProject,
    markModified,
    getLanguage,
  };
}