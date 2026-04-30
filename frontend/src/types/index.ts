export interface Tab {
  id: string;
  path: string;
  name: string;
  isModified: boolean;
  language: string;
}

export interface Project {
  id: string;
  name: string;
  path: string;
  is_active: boolean;
}

export interface FileEntry {
  name: string;
  path: string;
  is_directory: boolean;
  is_hidden: boolean;
}

export interface DirectoryListing {
  entries: FileEntry[];
  path: string;
}

export interface SearchResultItem {
  path: string;
  line: string;
  line_number: number;
  column: number;
  match_start: number;
  match_end: number;
}

export interface AppSettings {
  theme: {
    name: string;
    dark_mode: boolean;
    font_size: number;
    font_family: string;
    color_overrides: Record<string, string>;
  };
  editor: {
    tab_size: number;
    insert_spaces: boolean;
    word_wrap: string;
    minimap_enabled: boolean;
    line_numbers: boolean;
    render_whitespace: boolean;
  };
  terminal: {
    shell: string;
    font_size: number;
    scrollback: number;
  };
  ui: {
    activity_bar_visible: boolean;
    status_bar_visible: boolean;
    sidebar_width: number;
  };
}

export const DEFAULT_SETTINGS: AppSettings = {
  theme: {
    name: "dark",
    dark_mode: true,
    font_size: 13,
    font_family: "SF Mono",
    color_overrides: {},
  },
  editor: {
    tab_size: 4,
    insert_spaces: true,
    word_wrap: "off",
    minimap_enabled: false,
    line_numbers: true,
    render_whitespace: false,
  },
  terminal: {
    shell: "/bin/zsh",
    font_size: 13,
    scrollback: 10000,
  },
  ui: {
    activity_bar_visible: true,
    status_bar_visible: true,
    sidebar_width: 280,
  },
};