import { useEffect, useRef } from "react";
import { Terminal as XTerm } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import { onTerminalData, onTerminalExit, writeTerminal, resizeTerminal } from "@/lib/tauri";
import "@xterm/xterm/css/xterm.css";

interface TerminalComponentProps {
  terminalId: string;
  visible: boolean;
  fontSize: number;
  scrollback: number;
}

export function TerminalComponent({ terminalId, visible, fontSize, scrollback }: TerminalComponentProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const xtermRef = useRef<XTerm | null>(null);
  const fitAddonRef = useRef<FitAddon | null>(null);
  const unlistenDataRef = useRef<(() => void) | null>(null);
  const unlistenExitRef = useRef<(() => void) | null>(null);
  const visibleRef = useRef(visible);
  const terminalIdRef = useRef(terminalId);

  visibleRef.current = visible;
  terminalIdRef.current = terminalId;

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;

    const xterm = new XTerm({
      cursorBlink: true,
      fontSize,
      fontFamily: "'SF Mono', 'Fira Code', 'Cascadia Code', Consolas, 'Courier New', monospace",
      letterSpacing: 0,
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
      scrollback,
    });

    const fitAddon = new FitAddon();
    xterm.loadAddon(fitAddon);
    xterm.open(el);

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

    const dataDisposable = xterm.onData((data) => {
      writeTerminal(terminalIdRef.current, data).catch(() => {});
    });

    const resizeObserver = new ResizeObserver(() => {
      if (fitAddonRef.current && xtermRef.current) {
        try {
          fitAddonRef.current.fit();
        } catch {
          // ignore
        }
      }
    });
    resizeObserver.observe(el);

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
      dataDisposable.dispose();
      resizeObserver.disconnect();
      if (unlistenDataRef.current) {
        unlistenDataRef.current();
        unlistenDataRef.current = null;
      }
      if (unlistenExitRef.current) {
        unlistenExitRef.current();
        unlistenExitRef.current = null;
      }
      xterm.dispose();
      xtermRef.current = null;
      fitAddonRef.current = null;
    };
  }, [terminalId]);

  useEffect(() => {
    if (visible && xtermRef.current && fitAddonRef.current) {
      setTimeout(() => {
        try {
          fitAddonRef.current!.fit();
          resizeTerminal(terminalId, xtermRef.current!.rows, xtermRef.current!.cols).catch(() => {});
        } catch {
          // ignore
        }
      }, 10);
    }
  }, [visible, terminalId]);

  return (
    <div
      ref={containerRef}
      className="w-full h-full"
      style={{ padding: "4px", display: visible ? "block" : "none" }}
    />
  );
}