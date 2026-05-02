import { useEffect, useRef, useCallback } from "react";
import { Terminal as XTerm } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import { onTerminalData, onTerminalExit, writeTerminal, resizeTerminal } from "@/lib/tauri";
import "@xterm/xterm/css/xterm.css";

interface TerminalComponentProps {
  terminalId: string;
  visible: boolean;
}

export function TerminalComponent({ terminalId, visible }: TerminalComponentProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const xtermRef = useRef<XTerm | null>(null);
  const fitAddonRef = useRef<FitAddon | null>(null);
  const unlistenDataRef = useRef<(() => void) | null>(null);
  const unlistenExitRef = useRef<(() => void) | null>(null);
  const initRef = useRef(false);

  const handleResize = useCallback(() => {
    if (fitAddonRef.current && xtermRef.current && visible) {
      try {
        fitAddonRef.current.fit();
        resizeTerminal(terminalId, xtermRef.current.rows, xtermRef.current.cols).catch(() => {});
      } catch {
        // ignore fit errors when invisible
      }
    }
  }, [terminalId, visible]);

  useEffect(() => {
    if (!containerRef.current || initRef.current) return;
    initRef.current = true;

    const xterm = new XTerm({
      cursorBlink: true,
      fontSize: 13,
      fontFamily: "'SF Mono', 'Fira Code', Consolas, monospace",
      theme: {
        background: "#000000",
        foreground: "#ffffff",
        cursor: "#0070f3",
        selectionBackground: "#264f78",
        black: "#000000",
        red: "#cd3131",
        green: "#0dbc79",
        yellow: "#e5e510",
        blue: "#2472c8",
        magenta: "#bc3fbc",
        cyan: "#11a8cd",
        white: "#e5e5e5",
        brightBlack: "#666666",
        brightRed: "#f14c4c",
        brightGreen: "#23d18b",
        brightYellow: "#f5f543",
        brightBlue: "#3b8eea",
        brightMagenta: "#d670d6",
        brightCyan: "#29b8db",
        brightWhite: "#ffffff",
      },
      allowTransparency: true,
      scrollback: 10000,
    });

    const fitAddon = new FitAddon();
    xterm.loadAddon(fitAddon);
    xterm.open(containerRef.current);

    xtermRef.current = xterm;
    fitAddonRef.current = fitAddon;

    setTimeout(() => {
      try {
        fitAddon.fit();
        resizeTerminal(terminalId, xterm.rows, xterm.cols).catch(() => {});
      } catch {
        // ignore
      }
    }, 100);

    xterm.onData(async (data) => {
      try {
        await writeTerminal(terminalId, data);
      } catch {
        // terminal might be closed
      }
    });

    const resizeObserver = new ResizeObserver(() => {
      handleResize();
    });
    if (containerRef.current) {
      resizeObserver.observe(containerRef.current);
    }

    onTerminalData(terminalId, (data: string) => {
      if (xtermRef.current) {
        xtermRef.current.write(data);
      }
    }).then((unlisten) => {
      unlistenDataRef.current = unlisten;
    });

    onTerminalExit(terminalId, () => {
      if (xtermRef.current) {
        xtermRef.current.write("\r\n\x1b[31m[Process exited]\x1b[0m\r\n");
        xtermRef.current.options!.disableStdin = true;
      }
    }).then((unlisten) => {
      unlistenExitRef.current = unlisten;
    });

    return () => {
      resizeObserver.disconnect();
    };
  }, [terminalId, handleResize]);

  useEffect(() => {
    if (xtermRef.current && visible) {
      setTimeout(() => {
        try {
          fitAddonRef.current?.fit();
        } catch {
          // ignore
        }
      }, 10);
    }
  }, [visible]);

  useEffect(() => {
    return () => {
      if (unlistenDataRef.current) {
        unlistenDataRef.current();
        unlistenDataRef.current = null;
      }
      if (unlistenExitRef.current) {
        unlistenExitRef.current();
        unlistenExitRef.current = null;
      }
    };
  }, []);

  return (
    <div
      ref={containerRef}
      className="w-full h-full"
      style={{ padding: "4px", display: visible ? "block" : "none" }}
    />
  );
}