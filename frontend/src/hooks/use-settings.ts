import { useState, useCallback } from "react";
import type { AppSettings } from "@/types";
import { DEFAULT_SETTINGS } from "@/types";
import { getSettings, saveSettings as tauriSave } from "@/lib/tauri";

export function useSettings() {
  const [settings, setSettings] = useState<AppSettings>(() => {
    try {
      const saved = localStorage.getItem("codnia-settings");
      if (saved) return { ...DEFAULT_SETTINGS, ...JSON.parse(saved) };
    } catch {}
    return DEFAULT_SETTINGS;
  });
  const [isOpen, setIsOpen] = useState(false);

  const loadSettings = useCallback(async () => {
    try {
      const s = await getSettings();
      setSettings(s);
    } catch {
      setSettings(DEFAULT_SETTINGS);
    }
  }, []);

  const updateSettings = useCallback(
    (partial: Partial<AppSettings>) => {
      setSettings((prev) => {
        const next = { ...prev, ...partial };
        localStorage.setItem("codnia-settings", JSON.stringify(next));
        tauriSave(next).catch(console.error);
        return next;
      });
    },
    [],
  );

  const openSettings = useCallback(() => setIsOpen(true), []);
  const closeSettings = useCallback(() => setIsOpen(false), []);

  return { settings, isOpen, loadSettings, updateSettings, openSettings, closeSettings };
}