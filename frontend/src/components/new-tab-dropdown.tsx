import { useState, useRef, useEffect } from "react";

interface NewTabDropdownProps {
  onTerminal: () => void;
  onOpenCode: () => void;
  onClaudeCode: () => void;
  onCodex: () => void;
  onNewFile: () => void;
}

const menuItems = [
  {
    id: "terminal",
    label: "Terminal",
    shortcut: "Ctrl+`",
    icon: (
      <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <path d="M4 17l6-6-6-6" />
        <path d="M12 19h8" />
      </svg>
    ),
  },
  {
    id: "opencode",
    label: "OpenCode",
    shortcut: "Ctrl+Shift+O",
    icon: (
      <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <polyline points="16 18 22 12 16 6" />
        <polyline points="8 6 2 12 8 18" />
      </svg>
    ),
  },
  {
    id: "claude",
    label: "Claude Code",
    shortcut: "Ctrl+Shift+C",
    icon: (
      <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <circle cx="12" cy="12" r="3" />
        <path d="M12 2v4M12 18v4" />
      </svg>
    ),
  },
  {
    id: "codex",
    label: "Codex",
    shortcut: "Ctrl+Shift+X",
    icon: (
      <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" />
      </svg>
    ),
  },
  {
    id: "separator",
  },
  {
    id: "newfile",
    label: "New File",
    shortcut: "Ctrl+N",
    icon: (
      <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
        <polyline points="14 2 14 8 20 8" />
      </svg>
    ),
  },
];

export function NewTabDropdown({ onTerminal, onOpenCode, onClaudeCode, onCodex, onNewFile }: NewTabDropdownProps) {
  const [open, setOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    if (open) {
      document.addEventListener("mousedown", handleClickOutside);
    }
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, [open]);

  const handleSelect = (id: string) => {
    setOpen(false);
    switch (id) {
      case "terminal":
        onTerminal();
        break;
      case "opencode":
        onOpenCode();
        break;
      case "claude":
        onClaudeCode();
        break;
      case "codex":
        onCodex();
        break;
      case "newfile":
        onNewFile();
        break;
    }
  };

  return (
    <div className="relative" ref={dropdownRef}>
      <button
        onClick={() => setOpen(!open)}
        className="w-[28px] h-[28px] flex items-center justify-center rounded transition-colors text-[#555555] hover:bg-[#222222] hover:text-white"
        title="New Tab"
      >
        <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <path d="M12 5v14M5 12h14" />
        </svg>
      </button>

      {open && (
        <div className="absolute top-full left-0 mt-1 min-w-[200px] bg-[#111111] border border-[#2a2a2a] rounded-md shadow-lg z-50 overflow-hidden">
          {menuItems.map((item) => {
            if (item.id === "separator") {
              return <div key="separator" className="h-px bg-[#2a2a2a] my-1" />;
            }
            return (
              <button
                key={item.id}
                onClick={() => handleSelect(item.id)}
                className="flex items-center gap-[10px] px-[14px] py-[10px] text-[13px] text-[#888888] hover:bg-[#222222] hover:text-white w-full text-left transition-colors cursor-pointer"
              >
                {item.icon}
                <span className="flex-1">{item.label}</span>
                <span className="text-[11px] text-[#555555]">{item.shortcut}</span>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}