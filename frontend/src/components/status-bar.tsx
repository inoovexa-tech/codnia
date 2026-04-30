interface StatusBarProps {
  language: string;
  position: string;
  branch?: string;
}

export function StatusBar({ language, position, branch = "main" }: StatusBarProps) {
  return (
    <div className="h-[22px] bg-[#000000] flex items-center px-3 text-[11px] gap-4 border-t border-[#2a2a2a] shrink-0">
      <span className="flex items-center gap-1.5 text-[#888888] hover:text-white cursor-pointer">
        <svg className="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <circle cx="12" cy="12" r="4" />
        </svg>
        {branch}
      </span>
      <span className="text-[#888888]">0 problems</span>
      <span className="flex-1" />
      <span className="text-[#888888]">Spaces: 4</span>
      <span className="text-[#888888]">UTF-8</span>
      <span className="text-[#888888]">{language}</span>
      <span className="text-[#888888]">{position}</span>
    </div>
  );
}