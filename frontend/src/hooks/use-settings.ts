import { useState, useEffect, useCallback } from "react";
import { invoke } from "@tauri-apps/api/core";
import type { AppSettings } from "@/types";
import { DEFAULT_SETTINGS } from "@/types";

const STORAGE_KEY = "codnia-settings";

function loadFromStorage(): AppSettings | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw) as AppSettings;
  } catch {}
  return null;
}

function saveToStorage(settings: AppSettings) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
  } catch {}
}

export function useSettings() {
  const [settings, setSettings] = useState<AppSettings>(() => {
    return loadFromStorage() ?? DEFAULT_SETTINGS;
  });

  useEffect(() => {
    invoke<AppSettings>("get_settings")
      .then((s) => {
        setSettings(s);
        saveToStorage(s);
      })
      .catch(console.error);
  }, []);

  useEffect(() => {
    const handler = (e: StorageEvent) => {
      if (e.key === STORAGE_KEY && e.newValue) {
        try {
          setSettings(JSON.parse(e.newValue) as AppSettings);
        } catch {}
      }
    };
    window.addEventListener("storage", handler);
    return () => window.removeEventListener("storage", handler);
  }, []);

  const update = useCallback(
    async (partial: Partial<AppSettings>) => {
      const next = { ...settings, ...partial } as AppSettings;
      setSettings(next);
      saveToStorage(next);
      try {
        await invoke("save_settings", { settings: next });
      } catch (e) {
        console.error("Failed to save settings", e);
      }
    },
    [settings]
  );

  return { settings, update };
}