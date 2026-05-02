import { createRoot } from "react-dom/client";
import { useState, useCallback, useEffect, useRef } from "react";
import { invoke } from "@tauri-apps/api/core";
import { Minus, Square, X } from "lucide-react";
import { getCurrentWindow } from "@tauri-apps/api/window";
import {
  Tabs,
  TabsList,
  TabsTrigger,
  TabsContent,
} from "@/components/ui/tabs";
import { Switch } from "@/components/ui/switch";
import "./globals.css";
import type { AppSettings } from "./types";

const SHORTCUT_LABELS: Record<string, string> = {
  new_tab: "New Tab",
  toggle_terminal: "Toggle Terminal",
  run_opencode: "Run OpenCode",
  run_claude_code: "Run Claude Code",
  run_codex: "Run Codex",
  toggle_sidebar: "Toggle Sidebar",
  global_search: "Global Search",
  open_settings: "Open Settings",
  save_file: "Save File",
  save_file_as: "Save File As",
  close_tab: "Close Tab",
};

function formatShortcut(raw: string): string {
  return raw
    .replace("ctrl", "Ctrl")
    .replace("shift", "Shift")
    .replace("alt", "Alt")
    .replace("meta", "Cmd")
    .split("+")
    .map((p) => {
      if (p === "Cmd" || p === "Ctrl" || p === "Shift" || p === "Alt") return p;
      return p.length === 1 ? p.toUpperCase() : p.charAt(0).toUpperCase() + p.slice(1);
    })
    .join("+");
}

function ShortcutInput({
  value,
  onChange,
}: {
  value: string;
  onChange: (v: string) => void;
}) {
  const [recording, setRecording] = useState(false);
  const ref = useRef<HTMLButtonElement>(null);

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      e.preventDefault();
      e.stopPropagation();
      if (e.key === "Escape") {
        setRecording(false);
        return;
      }
      const parts: string[] = [];
      if (e.ctrlKey || e.metaKey) parts.push(e.ctrlKey ? "ctrl" : "meta");
      if (e.shiftKey) parts.push("shift");
      if (e.altKey) parts.push("alt");
      const key = e.key.toLowerCase();
      if (!["control", "shift", "alt", "meta"].includes(key)) {
        parts.push(key);
      }
      if (parts.length > 1 || (parts.length === 1 && !["ctrl", "shift", "alt", "meta"].includes(parts[0]))) {
        const combo = parts.join("+");
        onChange(combo);
        setRecording(false);
      }
    },
    [onChange]
  );

  return (
    <button
      ref={ref}
      onClick={() => setRecording(true)}
      onBlur={() => setRecording(false)}
      onKeyDown={recording ? handleKeyDown : undefined}
      className={`min-w-[120px] text-[11px] font-[var(--font-mono)] px-3 py-1.5 border rounded-[4px] transition-colors focus:outline-none ${
        recording
          ? "bg-[#1a1a1a] border-[#0070f3] text-[#0070f3]"
          : "bg-[#111111] border-[#222222] text-[#555555] hover:border-[#333333]"
      }`}
    >
      {recording ? "Press shortcut..." : formatShortcut(value)}
    </button>
  );
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

function App() {
  const [settings, setSettings] = useState<AppSettings | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    invoke<AppSettings>("get_settings").then(setSettings).catch(console.error);
  }, []);

  const update = useCallback(
    async (partial: Partial<AppSettings>) => {
      if (!settings) return;
      const next = { ...settings, ...partial } as AppSettings;
      setSettings(next);
      setSaving(true);
      try {
        await invoke("save_settings", { settings: next });
      } catch (e) {
        console.error("Failed to save settings", e);
      } finally {
        setSaving(false);
      }
    },
    [settings]
  );

  const updateShortcut = useCallback(
    (action: string, shortcut: string) => {
      if (!settings) return;
      const next = {
        ...settings,
        keyboard_shortcuts: {
          ...settings.keyboard_shortcuts,
          shortcuts: {
            ...settings.keyboard_shortcuts.shortcuts,
            [shortcut]: action,
          },
        },
      } as AppSettings;
      setSettings(next);
      setSaving(true);
      invoke("save_settings", { settings: next }).catch(console.error).finally(() => setSaving(false));
    },
    [settings]
  );

  if (!settings) {
    return (
      <div className="flex items-center justify-center w-full h-full bg-[#000000] text-white">
        <p className="text-[13px] text-[#555555]">Loading...</p>
      </div>
    );
  }

  const shortcutsMap = settings.keyboard_shortcuts?.shortcuts ?? {};
  const actionToShortcut: Record<string, string> = {};
  for (const [key, action] of Object.entries(shortcutsMap)) {
    actionToShortcut[action] = key;
  }

  return (
    <div className="flex flex-col w-full h-full bg-[#000000] text-white font-[var(--font-sans)]">
      {saving && (
        <div className="absolute top-2 right-4 bg-[#0070f3] text-white text-[11px] px-2.5 py-1 rounded-[4px] z-50">
          Saved
        </div>
      )}

      <Tabs defaultValue="editor" className="flex flex-col flex-1 overflow-hidden">
        <div className="h-8 shrink-0 border-b border-[#1a1a1a] flex items-center" data-tauri-drag-region>
          <TabsList className="flex-1" data-tauri-drag-region>
            <TabsTrigger value="editor">Editor</TabsTrigger>
            <TabsTrigger value="theme">Appearance</TabsTrigger>
            <TabsTrigger value="terminal">Terminal</TabsTrigger>
            <TabsTrigger value="shortcuts">Keyboard</TabsTrigger>
          </TabsList>
          <div className="flex items-center shrink-0" style={{ paddingLeft: 8, paddingRight: 12, borderLeft: "1px solid #1a1a1a" }}>
            <WindowControls />
          </div>
        </div>

        <TabsContent value="editor" className="flex-1 overflow-y-auto">
          <div className="px-20 py-10">
            <h3 className="text-[11px] font-semibold text-[#555555] uppercase tracking-widest mb-4">Editor</h3>
            <div className="bg-[#0a0a0a] border border-[#1a1a1a] rounded-[6px]">
              <SettingRow label="Minimap" description="Show code overview on the side">
                <Switch checked={settings.editor.minimap_enabled} onCheckedChange={(checked) => update({ editor: { ...settings.editor, minimap_enabled: checked } })} />
              </SettingRow>
              <SettingRow label="Line Numbers" description="Show line numbers in editor">
                <Switch checked={settings.editor.line_numbers} onCheckedChange={(checked) => update({ editor: { ...settings.editor, line_numbers: checked } })} />
              </SettingRow>
              <SettingRow label="Word Wrap" description="Wrap long lines">
                <Switch
                  checked={settings.editor.word_wrap === "on"}
                  onCheckedChange={(checked) =>
                    update({ editor: { ...settings.editor, word_wrap: checked ? "on" : "off" } })
                  }
                />
              </SettingRow>
            </div>

            <h3 className="text-[11px] font-semibold text-[#555555] uppercase tracking-widest mb-4 mt-10">Indentation</h3>
            <div className="bg-[#0a0a0a] border border-[#1a1a1a] rounded-[6px]">
              <SettingRow label="Tab Size" description="Number of spaces per indent">
                <select
                  value={settings.editor.tab_size}
                  onChange={(e) => update({ editor: { ...settings.editor, tab_size: Number(e.target.value) } })}
                  className="bg-[#111111] border border-[#1a1a1a] rounded-[4px] px-3 py-1.5 text-[12px] text-white focus:outline-none focus:border-[#0070f3]"
                >
                  <option value="2">2 spaces</option>
                  <option value="4">4 spaces</option>
                  <option value="8">8 spaces</option>
                </select>
              </SettingRow>
              <SettingRow label="Insert Spaces" description="Use spaces instead of tabs">
                <Switch checked={settings.editor.insert_spaces} onCheckedChange={(checked) => update({ editor: { ...settings.editor, insert_spaces: checked } })} />
              </SettingRow>
            </div>
          </div>
        </TabsContent>

        <TabsContent value="theme" className="flex-1 overflow-y-auto">
          <div className="px-20 py-10">
            <h3 className="text-[11px] font-semibold text-[#555555] uppercase tracking-widest mb-4">Font</h3>
            <div className="bg-[#0a0a0a] border border-[#1a1a1a] rounded-[6px]">
              <SettingRow label="Font Size" description="Editor font size in pixels">
                <input
                  type="number"
                  min={10}
                  max={24}
                  value={settings.theme.font_size}
                  onChange={(e) => update({ theme: { ...settings.theme, font_size: Number(e.target.value) } })}
                  className="w-[72px] bg-[#111111] border border-[#1a1a1a] rounded-[4px] px-3 py-1.5 text-[12px] text-white text-center focus:outline-none focus:border-[#0070f3]"
                />
              </SettingRow>
              <SettingRow label="Font Family" description="Font used in editor and UI">
                <input
                  type="text"
                  value={settings.theme.font_family}
                  onChange={(e) => update({ theme: { ...settings.theme, font_family: e.target.value } })}
                  className="w-60 bg-[#111111] border border-[#1a1a1a] rounded-[4px] px-3 py-1.5 text-[12px] text-white focus:outline-none focus:border-[#0070f3]"
                />
              </SettingRow>
            </div>
          </div>
        </TabsContent>

        <TabsContent value="terminal" className="flex-1 overflow-y-auto">
          <div className="px-20 py-10">
            <h3 className="text-[11px] font-semibold text-[#555555] uppercase tracking-widest mb-4">Terminal</h3>
            <div className="bg-[#0a0a0a] border border-[#1a1a1a] rounded-[6px]">
              <SettingRow label="Shell" description="Shell used for terminal sessions">
                <input
                  type="text"
                  value={settings.terminal.shell}
                  onChange={(e) => update({ terminal: { ...settings.terminal, shell: e.target.value } })}
                  className="w-60 bg-[#111111] border border-[#1a1a1a] rounded-[4px] px-3 py-1.5 text-[12px] text-white focus:outline-none focus:border-[#0070f3]"
                />
              </SettingRow>
              <SettingRow label="Font Size" description="Terminal font size in pixels">
                <input
                  type="number"
                  min={10}
                  max={24}
                  value={settings.terminal.font_size}
                  onChange={(e) => update({ terminal: { ...settings.terminal, font_size: Number(e.target.value) } })}
                  className="w-[72px] bg-[#111111] border border-[#1a1a1a] rounded-[4px] px-3 py-1.5 text-[12px] text-white text-center focus:outline-none focus:border-[#0070f3]"
                />
              </SettingRow>
            </div>
          </div>
        </TabsContent>

        <TabsContent value="shortcuts" className="flex-1 overflow-y-auto">
          <div className="px-20 py-10">
            <h3 className="text-[11px] font-semibold text-[#555555] uppercase tracking-widest mb-4">Keyboard Shortcuts</h3>
            <div className="bg-[#0a0a0a] border border-[#1a1a1a] rounded-[6px]">
              {Object.entries(SHORTCUT_LABELS).map(([action, label]) => {
                const shortcut = actionToShortcut[action] || "";
                return (
                  <div key={action} className="flex items-center justify-between px-5 py-5 border-b border-[#1a1a1a] last:border-b-0">
                    <span className="text-[13px] text-[#888888]">{label}</span>
                    <ShortcutInput
                      value={shortcut}
                      onChange={(newShortcut) => updateShortcut(action, newShortcut)}
                    />
                  </div>
                );
              })}
            </div>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  );
}

function SettingRow({
  label,
  description,
  children,
}: {
  label: string;
  description: string;
  children: React.ReactNode;
}) {
  return (
    <div className="flex items-center justify-between px-5 py-5 border-b border-[#1a1a1a] last:border-b-0">
      <div className="min-w-0 flex-1 pr-6">
        <p className="text-[13px] text-white leading-relaxed">{label}</p>
        <p className="text-[11px] text-[#555555] mt-1 leading-relaxed">{description}</p>
      </div>
      <div className="shrink-0">
        {children}
      </div>
    </div>
  );
}

const root = createRoot(document.getElementById("app")!);
root.render(<App />);