import { useState, useCallback, useRef } from "react";
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

function getFileIcon(filename: string): string {
  const ext = filename.split(".").pop()?.toLowerCase() || "";
  const icons: Record<string, string> = {
    rs: "\u{1F980}", ts: "\u{1F4D8}", tsx: "\u269B", js: "\u{1F4DC}",
    jsx: "\u269B", json: "\u{1F4CB}", html: "\u{1F310}", css: "\u{1F3A8}",
    md: "\u{1F4DD}", toml: "\u2699", yaml: "\u{1F4C4}", yml: "\u{1F4C4}",
    sh: "\u{1F5A5}", bash: "\u{1F5A5}", png: "\u{1F5BC}", jpg: "\u{1F5BC}",
    jpeg: "\u{1F5BC}", gif: "\u{1F5BC}", svg: "\u{1F5BC}", txt: "\u{1F4C4}",
  };
  return icons[ext] || "\u{1F4C4}";
}

export function useEditor() {
  const editorRef = useRef<monaco.editor.IStandaloneCodeEditor | null>(null);
  const [tabs, setTabs] = useState<Tab[]>([]);
  const [activeTabId, setActiveTabId] = useState<string | null>(null);

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
  }, []);

  const openFile = useCallback(async (path: string) => {
    if (!editorRef.current) return;

    const existing = tabs.find((t) => t.path === path);
    if (existing) {
      setActiveTabId(existing.id);
      return;
    }

    const name = path.split("/").pop() || path;
    const language = getLanguage(name);
    const content = await readFile(path);

    const model = monaco.editor.createModel(content, language);
    editorRef.current.setModel(model);

    const tab: Tab = {
      id: `file-${Date.now()}`,
      path,
      name,
      isModified: false,
      language,
    };

    setTabs((prev) => [...prev, tab]);
    setActiveTabId(tab.id);
  }, [tabs]);

  const closeTab = useCallback(
    (tabId: string) => {
      setTabs((prev) => {
        const idx = prev.findIndex((t) => t.id === tabId);
        const next = prev.filter((t) => t.id !== tabId);
        if (activeTabId === tabId) {
          const newActive = next[Math.max(0, idx - 1)]?.id || null;
          setActiveTabId(newActive);
        }
        return next;
      });
    },
    [activeTabId],
  );

  const activateTab = useCallback(
    async (tabId: string) => {
      const tab = tabs.find((t) => t.id === tabId);
      if (!tab || !editorRef.current) return;

      setActiveTabId(tabId);
      const content = await readFile(tab.path);
      const model = monaco.editor.createModel(content, tab.language);
      editorRef.current.setModel(model);
    },
    [tabs],
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
    getFileIcon,
  };
}