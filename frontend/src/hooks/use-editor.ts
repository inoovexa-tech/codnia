import { useState, useCallback, useRef, useEffect } from "react";
import * as monaco from "monaco-editor";
import { readFile } from "@/lib/tauri";
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

export function useEditor() {
  const editorRef = useRef<monaco.editor.IStandaloneCodeEditor | null>(null);
  const [tabs, setTabs] = useState<Tab[]>([]);
  const [activeTabId, setActiveTabId] = useState<string | null>(null);
  const tabsRef = useRef<Tab[]>([]);
  const pendingFileRef = useRef<Tab | null>(null);

  // Manter tabsRef sincronizado
  useEffect(() => {
    tabsRef.current = tabs;
  }, [tabs]);

  const initEditor = useCallback((container: HTMLElement) => {
    if (editorRef.current) return;

    const saved = localStorage.getItem("codnia-settings");
    const settings = saved ? JSON.parse(saved) : { minimap: false };

    const editor = monaco.editor.create(container, {
      value: "",
      language: "plaintext",
      theme: "vs-dark",
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
      const uri = monaco.Uri.file(tab.path);
      const existingModel = monaco.editor.getModel(uri);
      if (existingModel) {
        editorRef.current.setModel(existingModel);
      } else {
        const content = await readFile(tab.path);
        const model = monaco.editor.createModel(content, tab.language, uri);
        editorRef.current.setModel(model);
      }
    },
    [],
  );

  return {
    editorRef,
    tabs,
    activeTabId,
    initEditor,
    openFile,
    closeTab,
    activateTab,
    getLanguage,
  };
}
