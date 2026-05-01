import { Plus, Terminal, Code2, Circle, Layers, FilePlus } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu";

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
    icon: <Terminal className="h-4 w-4" />,
  },
  {
    id: "opencode",
    label: "OpenCode",
    shortcut: "Ctrl+Shift+O",
    icon: <Code2 className="h-4 w-4" />,
  },
  {
    id: "claude",
    label: "Claude Code",
    shortcut: "Ctrl+Shift+C",
    icon: <Circle className="h-4 w-4" />,
  },
  {
    id: "codex",
    label: "Codex",
    shortcut: "Ctrl+Shift+X",
    icon: <Layers className="h-4 w-4" />,
  },
  { id: "separator" },
  {
    id: "newfile",
    label: "New File",
    shortcut: "Ctrl+N",
    icon: <FilePlus className="h-4 w-4" />,
  },
];

export function NewTabDropdown({ onTerminal, onOpenCode, onClaudeCode, onCodex, onNewFile }: NewTabDropdownProps) {
  const handleSelect = (id: string) => {
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
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          className="w-[28px] h-[28px] flex items-center justify-center rounded transition-colors text-[#555555] hover:bg-[#222222] hover:text-white cursor-pointer"
          title="New Tab"
          type="button"
        >
          <Plus className="h-4 w-4" />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" sideOffset={8} className="w-[220px]">
        {menuItems.map((item) => {
          if (item.id === "separator") {
            return <DropdownMenuSeparator key="separator" />;
          }
          return (
            <DropdownMenuItem
              key={item.id}
              onClick={() => handleSelect(item.id)}
              className="flex items-center gap-[10px] px-[14px] py-[10px] text-[13px] cursor-pointer"
            >
              {item.icon}
              <span className="flex-1">{item.label}</span>
              <span className="text-[11px] text-text-tertiary">{item.shortcut}</span>
            </DropdownMenuItem>
          );
        })}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
