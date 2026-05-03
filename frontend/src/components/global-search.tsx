import { useState, useCallback, useRef, useEffect } from "react";
import { Search, File, ChevronRight, ChevronDown, FolderOpen } from "lucide-react";
import { searchContentAdvanced, searchFilesAdvanced } from "@/lib/tauri";

interface GlobalSearchProps {
  rootPath: string | undefined;
  onFileSelect: (path: string) => void;
}

interface ContentMatch {
  path: string;
  line_number: number;
  line: string;
}

interface GroupedResults {
  [filePath: string]: ContentMatch[];
}

export function GlobalSearch({ rootPath, onFileSelect }: GlobalSearchProps) {
  const [query, setQuery] = useState("");
  const [contentResults, setContentResults] = useState<GroupedResults>({});
  const [fileResults, setFileResults] = useState<string[]>([]);
  const [totalMatches, setTotalMatches] = useState(0);
  const [elapsedMs, setElapsedMs] = useState(0);
  const [isSearching, setIsSearching] = useState(false);
  const [expandedPaths, setExpandedPaths] = useState<Set<string>>(new Set());
  const [hasSearched, setHasSearched] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const togglePath = useCallback((path: string) => {
    setExpandedPaths((prev) => {
      const next = new Set(prev);
      if (next.has(path)) next.delete(path);
      else next.add(path);
      return next;
    });
  }, []);

  const handleSearch = useCallback(
    (value: string) => {
      setQuery(value);
      if (debounceRef.current) clearTimeout(debounceRef.current);
      if (!value.trim() || !rootPath) {
        setContentResults({});
        setFileResults([]);
        setTotalMatches(0);
        setElapsedMs(0);
        setHasSearched(false);
        return;
      }
      debounceRef.current = setTimeout(async () => {
        setIsSearching(true);
        try {
          const [contentData, filesData] = await Promise.all([
            searchContentAdvanced(rootPath, value, false, false, 200),
            searchFilesAdvanced(rootPath, value, 100),
          ]);
          const grouped: GroupedResults = {};
          for (const m of contentData.matches) {
            if (!grouped[m.path]) grouped[m.path] = [];
            grouped[m.path].push(m);
          }
          const matchedFilePaths = new Set(Object.keys(grouped));
          const filesOnly = filesData.filter((p) => !matchedFilePaths.has(p));
          setContentResults(grouped);
          setFileResults(filesOnly);
          setTotalMatches(contentData.total_matches + filesOnly.length);
          setElapsedMs(contentData.elapsed_ms);
          setExpandedPaths(new Set(Object.keys(grouped)));
          setHasSearched(true);
        } catch (e) {
          console.error("Search failed:", e);
        } finally {
          setIsSearching(false);
        }
      }, 250);
    },
    [rootPath]
  );

  useEffect(() => {
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, []);

  const highlightMatch = (text: string, q: string) => {
    if (!q) return text;
    const lower = text.toLowerCase();
    const lowerQ = q.toLowerCase();
    const idx = lower.indexOf(lowerQ);
    if (idx === -1) return text;
    return (
      <>
        <span>{text.slice(0, idx)}</span>
        <span className="bg-[#264f78] text-[#e2c08d] rounded-[2px] px-[1px]">{text.slice(idx, idx + q.length)}</span>
        <span>{text.slice(idx + q.length)}</span>
      </>
    );
  };

  const getRelativePath = (fullPath: string) => {
    if (!rootPath) return fullPath;
    return fullPath.startsWith(rootPath) ? fullPath.slice(rootPath.length + 1) : fullPath;
  };

  const getFileName = (fullPath: string) => {
    const parts = fullPath.split("/");
    return parts[parts.length - 1] || fullPath;
  };

  const getDirPath = (fullPath: string) => {
    const rel = getRelativePath(fullPath);
    const idx = rel.lastIndexOf("/");
    return idx > 0 ? rel.slice(0, idx) : "";
  };

  const contentFileCount = Object.keys(contentResults).length;
  const fileOnlyCount = fileResults.length;
  const hasResults = contentFileCount > 0 || fileOnlyCount > 0;

  return (
    <div className="flex flex-col h-full overflow-hidden bg-[#0e0e0e]">
      {/* Search input area */}
      <div className="shrink-0" style={{ padding: "12px 12px 8px 12px" }}>
        <div className="relative">
          <Search className="absolute left-[10px] top-[50%] -translate-y-[50%] h-[14px] w-[14px] text-[#4a4a4a] pointer-events-none" />
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => handleSearch(e.target.value)}
            placeholder="Search files and content..."
            className="block w-full h-[32px] bg-[#1a1a1a] border border-[#2e2e2e] rounded-[4px] text-[13px] text-white placeholder:text-[#4a4a4a] focus:outline-none focus:border-[#0070f3] transition-colors"
            style={{ paddingLeft: "32px", paddingRight: isSearching ? "32px" : "12px" }}
            autoFocus
          />
          {isSearching && (
            <div className="absolute right-[10px] top-[50%] -translate-y-[50%]">
              <div className="w-[14px] h-[14px] border-2 border-[#333333] border-t-[#0070f3] rounded-full animate-spin" />
            </div>
          )}
        </div>
      </div>

      {/* Status line */}
      {query.trim() && (
        <div className="shrink-0 text-[11px] text-[#4a4a4a]" style={{ padding: "0 12px 8px 12px" }}>
          {isSearching
            ? "Searching..."
            : hasResults
              ? `${totalMatches} result${totalMatches !== 1 ? "s" : ""} in ${contentFileCount + fileOnlyCount} file${(contentFileCount + fileOnlyCount) !== 1 ? "s" : ""}${elapsedMs > 0 ? ` · ${elapsedMs}ms` : ""}`
              : "No results found"}
        </div>
      )}

      {/* Empty state */}
      {!hasSearched && !query.trim() && (
        <div className="flex-1 flex items-center justify-center" style={{ padding: "0 24px" }}>
          <div className="flex flex-col items-center gap-4">
            <Search className="h-12 w-12 text-[#1e1e1e]" />
            <div className="text-center">
              <p className="text-[13px] text-[#444444]">Search across files and content</p>
              <p className="text-[11px] text-[#333333] mt-2 font-mono bg-[#1a1a1a] inline-block px-2 py-1 rounded">Ctrl+Shift+F</p>
            </div>
          </div>
        </div>
      )}

      {/* Results */}
      {hasResults && (
        <div className="flex-1 overflow-y-auto pb-4">
          {/* Content matches */}
          {contentFileCount > 0 && (
            <div>
              <div className="text-[11px] font-semibold text-[#4a4a4a] uppercase tracking-wider" style={{ padding: "10px 12px 4px 12px" }}>
                Content
              </div>
              {Object.entries(contentResults).map(([filePath, matches]) => {
                const isExpanded = expandedPaths.has(filePath);
                const fileName = getFileName(filePath);
                const dirPath = getDirPath(filePath);
                return (
                  <div key={filePath}>
                    <button
                      onClick={() => togglePath(filePath)}
                      className="w-full flex items-center gap-2 text-[13px] text-[#cccccc] hover:bg-[#181818] transition-colors text-left"
                      style={{ padding: "5px 12px" }}
                    >
                      {isExpanded ? (
                        <ChevronDown className="h-[14px] w-[14px] shrink-0 text-[#555555]" />
                      ) : (
                        <ChevronRight className="h-[14px] w-[14px] shrink-0 text-[#555555]" />
                      )}
                      <FolderOpen className="h-4 w-4 shrink-0 text-[#c09552]" />
                      <div className="min-w-0 flex-1">
                        <span className="truncate font-medium">{highlightMatch(fileName, query)}</span>
                      </div>
                      {dirPath && (
                        <span className="text-[11px] text-[#3a3a3a] truncate max-w-[80px] shrink-0">
                          {dirPath}
                        </span>
                      )}
                      <span className="text-[10px] text-[#3a3a3a] bg-[#1a1a1a] rounded-full min-w-[20px] h-[18px] flex items-center justify-center shrink-0">
                        {matches.length}
                      </span>
                    </button>
                    {isExpanded && (
                      <div className="border-l border-[#1c1c1c] ml-[24px]">
                        {matches.slice(0, 20).map((m, i) => (
                          <button
                            key={`${filePath}-${i}`}
                            onClick={() => onFileSelect(filePath)}
                            className="w-full flex items-start gap-2.5 text-[12px] text-[#999999] hover:bg-[#181818] transition-colors text-left"
                            style={{ padding: "4px 12px 4px 16px" }}
                          >
                            <span className="text-[11px] text-[#3a3a3a] shrink-0 w-6 text-right tabular-nums pt-[1px]">
                              {m.line_number}
                            </span>
                            <span className="truncate leading-[1.5]">{highlightMatch(m.line.trim(), query)}</span>
                          </button>
                        ))}
                        {matches.length > 20 && (
                          <div className="text-[11px] text-[#3a3a3a]" style={{ padding: "4px 12px 4px 16px" }}>
                            +{matches.length - 20} more matches
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}

          {/* File name matches */}
          {fileOnlyCount > 0 && (
            <div className={contentFileCount > 0 ? "mt-5" : ""}>
              <div className="text-[11px] font-semibold text-[#4a4a4a] uppercase tracking-wider" style={{ padding: "10px 12px 4px 12px" }}>
                File Names
              </div>
              {fileResults.map((filePath) => {
                const fileName = getFileName(filePath);
                const dirPath = getDirPath(filePath);
                return (
                  <button
                    key={filePath}
                    onClick={() => onFileSelect(filePath)}
                    className="w-full flex items-center gap-2 text-[13px] text-[#cccccc] hover:bg-[#181818] transition-colors text-left"
                    style={{ padding: "5px 12px" }}
                  >
                    <File className="h-4 w-4 shrink-0 text-[#4a4a4a]" />
                    <div className="min-w-0 flex-1">
                      <span className="truncate font-medium">{highlightMatch(fileName, query)}</span>
                    </div>
                    {dirPath && (
                      <span className="text-[11px] text-[#3a3a3a] truncate max-w-[100px] shrink-0">
                        {dirPath}
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* No results state */}
      {query.trim() && !isSearching && !hasResults && hasSearched && (
        <div className="flex-1 flex items-center justify-center" style={{ padding: "0 24px" }}>
          <div className="flex flex-col items-center gap-3">
            <Search className="h-8 w-8 text-[#1e1e1e]" />
            <span className="text-[13px] text-[#444444]">No results for &ldquo;{query}&rdquo;</span>
          </div>
        </div>
      )}
    </div>
  );
}