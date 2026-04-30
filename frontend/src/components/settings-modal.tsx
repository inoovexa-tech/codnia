import { Switch } from "@/components/ui/switch";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import type { AppSettings } from "@/types";

interface SettingsModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  settings: AppSettings;
  onSettingsChange: (settings: Partial<AppSettings>) => void;
}

export function SettingsModal({ open, onOpenChange, settings, onSettingsChange }: SettingsModalProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[70vh]">
        <DialogHeader>
          <DialogTitle>Settings</DialogTitle>
        </DialogHeader>
        <Tabs defaultValue="editor" className="flex-1 overflow-hidden flex flex-col">
          <TabsList className="w-full">
            <TabsTrigger value="editor">Editor</TabsTrigger>
            <TabsTrigger value="theme">Theme</TabsTrigger>
            <TabsTrigger value="shortcuts">Keyboard</TabsTrigger>
            <TabsTrigger value="terminal">Terminal</TabsTrigger>
          </TabsList>
          <ScrollArea className="flex-1 mt-2 max-h-[400px]">
            <TabsContent value="editor" className="px-4 py-2 space-y-6">
              <div>
                <h3 className="text-[11px] font-semibold text-[#555555] uppercase tracking-wide mb-3">
                  Editor Settings
                </h3>
                <div className="space-y-4">
                  <div className="flex items-center justify-between py-2 border-b border-[#2a2a2a]">
                    <div>
                      <span className="text-[13px] text-white">Minimap</span>
                      <p className="text-[11px] text-[#555555]">Show code overview on the right</p>
                    </div>
                    <Switch
                      checked={settings.editor.minimap_enabled}
                      onCheckedChange={(checked) =>
                        onSettingsChange({
                          editor: { ...settings.editor, minimap_enabled: checked },
                        })
                      }
                    />
                  </div>
                  <div className="flex items-center justify-between py-2 border-b border-[#2a2a2a]">
                    <div>
                      <span className="text-[13px] text-white">Line Numbers</span>
                      <p className="text-[11px] text-[#555555]">Show line numbers in editor</p>
                    </div>
                    <Switch
                      checked={settings.editor.line_numbers}
                      onCheckedChange={(checked) =>
                        onSettingsChange({
                          editor: { ...settings.editor, line_numbers: checked },
                        })
                      }
                    />
                  </div>
                  <div className="flex items-center justify-between py-2 border-b border-[#2a2a2a]">
                    <div>
                      <span className="text-[13px] text-white">Word Wrap</span>
                      <p className="text-[11px] text-[#555555]">Wrap long lines</p>
                    </div>
                    <Switch
                      checked={settings.editor.word_wrap === "on"}
                      onCheckedChange={(checked) =>
                        onSettingsChange({
                          editor: { ...settings.editor, word_wrap: checked ? "on" : "off" },
                        })
                      }
                    />
                  </div>
                </div>
              </div>
              <div>
                <h3 className="text-[11px] font-semibold text-[#555555] uppercase tracking-wide mb-3">
                  Indentation
                </h3>
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-[13px] text-white">Tab Size</span>
                    <select
                      value={settings.editor.tab_size}
                      onChange={(e) =>
                        onSettingsChange({
                          editor: { ...settings.editor, tab_size: Number(e.target.value) },
                        })
                      }
                      className="bg-[#1a1a1a] border border-[#2a2a2a] rounded px-2 py-1 text-[12px] text-white"
                    >
                      <option value="2">2 spaces</option>
                      <option value="4">4 spaces</option>
                      <option value="8">8 spaces</option>
                    </select>
                  </div>
                  <div className="flex items-center justify-between py-2 border-b border-[#2a2a2a]">
                    <div>
                      <span className="text-[13px] text-white">Insert Spaces</span>
                      <p className="text-[11px] text-[#555555]">Use spaces instead of tabs</p>
                    </div>
                    <Switch
                      checked={settings.editor.insert_spaces}
                      onCheckedChange={(checked) =>
                        onSettingsChange({
                          editor: { ...settings.editor, insert_spaces: checked },
                        })
                      }
                    />
                  </div>
                </div>
              </div>
            </TabsContent>

            <TabsContent value="theme" className="px-4 py-2 space-y-6">
              <div>
                <h3 className="text-[11px] font-semibold text-[#555555] uppercase tracking-wide mb-3">
                  Theme
                </h3>
                <div className="flex items-center justify-between">
                  <span className="text-[13px] text-white">Color Theme</span>
                  <select
                    value={settings.theme.name}
                    onChange={(e) =>
                      onSettingsChange({
                        theme: { ...settings.theme, name: e.target.value },
                      })
                    }
                    className="bg-[#1a1a1a] border border-[#2a2a2a] rounded px-2 py-1 text-[12px] text-white"
                  >
                    <option value="dark">Dark</option>
                    <option value="light">Light</option>
                    <option value="high-contrast">High Contrast</option>
                  </select>
                </div>
              </div>
              <div>
                <h3 className="text-[11px] font-semibold text-[#555555] uppercase tracking-wide mb-3">
                  Font
                </h3>
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-[13px] text-white">Font Size</span>
                    <input
                      type="number"
                      value={settings.theme.font_size}
                      onChange={(e) =>
                        onSettingsChange({
                          theme: { ...settings.theme, font_size: Number(e.target.value) },
                        })
                      }
                      min={10}
                      max={24}
                      className="w-20 bg-[#1a1a1a] border border-[#2a2a2a] rounded px-2 py-1 text-[12px] text-white text-center"
                    />
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-[13px] text-white">Font Family</span>
                    <input
                      type="text"
                      value={settings.theme.font_family}
                      onChange={(e) =>
                        onSettingsChange({
                          theme: { ...settings.theme, font_family: e.target.value },
                        })
                      }
                      className="w-40 bg-[#1a1a1a] border border-[#2a2a2a] rounded px-2 py-1 text-[12px] text-white"
                    />
                  </div>
                </div>
              </div>
            </TabsContent>

            <TabsContent value="shortcuts" className="px-4 py-2">
              <h3 className="text-[11px] font-semibold text-[#555555] uppercase tracking-wide mb-3">
                Keyboard Shortcuts
              </h3>
              <div>
                {[
                  ["New Tab", "Ctrl+N"],
                  ["Toggle Terminal", "Ctrl+`"],
                  ["Run OpenCode", "Ctrl+Shift+O"],
                  ["Run Claude Code", "Ctrl+Shift+C"],
                  ["Global Search", "Ctrl+Shift+F"],
                  ["Open Settings", "Ctrl+,"],
                ].map(([action, shortcut]) => (
                  <div
                    key={action}
                    className="flex items-center justify-between py-2 border-b border-[#2a2a2a]"
                  >
                    <span className="text-[12px] text-[#888888]">{action}</span>
                    <kbd className="bg-[#1a1a1a] border border-[#2a2a2a] rounded px-2 py-1 text-[11px] text-white font-inherit">
                      {shortcut}
                    </kbd>
                  </div>
                ))}
              </div>
            </TabsContent>

            <TabsContent value="terminal" className="px-4 py-2 space-y-4">
              <h3 className="text-[11px] font-semibold text-[#555555] uppercase tracking-wide mb-3">
                Terminal
              </h3>
              <div className="flex items-center justify-between">
                <span className="text-[13px] text-white">Shell</span>
                <input
                  type="text"
                  value={settings.terminal.shell}
                  onChange={(e) =>
                    onSettingsChange({
                      terminal: { ...settings.terminal, shell: e.target.value },
                    })
                  }
                  className="w-40 bg-[#1a1a1a] border border-[#2a2a2a] rounded px-2 py-1 text-[12px] text-white"
                />
              </div>
              <div className="flex items-center justify-between">
                <span className="text-[13px] text-white">Font Size</span>
                <input
                  type="number"
                  value={settings.terminal.font_size}
                  onChange={(e) =>
                    onSettingsChange({
                      terminal: { ...settings.terminal, font_size: Number(e.target.value) },
                    })
                  }
                  min={10}
                  max={24}
                  className="w-20 bg-[#1a1a1a] border border-[#2a2a2a] rounded px-2 py-1 text-[12px] text-white text-center"
                />
              </div>
            </TabsContent>
          </ScrollArea>
        </Tabs>
      </DialogContent>
    </Dialog>
  );
}