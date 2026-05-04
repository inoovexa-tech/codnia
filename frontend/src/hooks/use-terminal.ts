import { useCallback } from "react";
import {
  createTerminal,
  writeTerminal,
  resizeTerminal,
  killTerminal,
} from "@/lib/tauri";

export function useTerminal() {
  const create = useCallback(async (options?: { cwd?: string; shell?: string; command?: string }) => {
    const instance = await createTerminal(options);
    return instance;
  }, []);

  const write = useCallback(async (id: string, data: string) => {
    await writeTerminal(id, data);
  }, []);

  const resize = useCallback(async (id: string, rows: number, cols: number) => {
    await resizeTerminal(id, rows, cols);
  }, []);

  const kill = useCallback(async (id: string) => {
    await killTerminal(id);
  }, []);

  return { create, write, resize, kill };
}