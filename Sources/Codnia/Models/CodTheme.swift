import Foundation

struct CodThemePalette: Codable, Equatable {
    var bg: String
    var fg: String
    var accent: String
    var surface: String
    var syntax: String
    var syntax2: String?
    var syntax3: String?
    var comment: String?
}

struct CodTheme: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let appearance: String
    let palette: CodThemePalette
}

extension CodTheme {
    static let builtin: [CodTheme] = [
        CodTheme(name: "Codnia Dark", appearance: "dark", palette: CodThemePalette(
            bg: "#1e1e1e", fg: "#d4d4d4", accent: "#569cd6", surface: "#252526", syntax: "#569cd6",
            syntax2: "#ce9178", syntax3: "#4ec9b0", comment: "#6a9955"
        )),
        CodTheme(name: "Dark+", appearance: "dark", palette: CodThemePalette(
            bg: "#1e1e1e", fg: "#d4d4d4", accent: "#569cd6", surface: "#252526", syntax: "#569cd6",
            syntax2: "#ce9178", syntax3: "#4ec9b0", comment: "#6a9955"
        )),
        CodTheme(name: "Monokai", appearance: "dark", palette: CodThemePalette(
            bg: "#272822", fg: "#f8f8f2", accent: "#a6e22e", surface: "#2c2d2a", syntax: "#f92672",
            syntax2: "#e6db74", syntax3: "#a6e22e", comment: "#75715e"
        )),
        CodTheme(name: "Dracula", appearance: "dark", palette: CodThemePalette(
            bg: "#282a36", fg: "#f8f8f2", accent: "#bd93f9", surface: "#21222c", syntax: "#ff79c6",
            syntax2: "#f1fa8c", syntax3: "#8be9fd", comment: "#6272a4"
        )),
        CodTheme(name: "Nord", appearance: "dark", palette: CodThemePalette(
            bg: "#2e3440", fg: "#eceff4", accent: "#88c0d0", surface: "#3b4252", syntax: "#81a1c1",
            syntax2: "#a3be8c", syntax3: "#b48ead", comment: "#616e88"
        )),
        CodTheme(name: "One Dark Pro", appearance: "dark", palette: CodThemePalette(
            bg: "#282c34", fg: "#abb2bf", accent: "#61afef", surface: "#2c313a", syntax: "#c678dd",
            syntax2: "#98c379", syntax3: "#e5c07b", comment: "#5c6370"
        )),
        CodTheme(name: "Tokyo Night", appearance: "dark", palette: CodThemePalette(
            bg: "#1a1b26", fg: "#c0caf5", accent: "#7aa2f7", surface: "#24283b", syntax: "#bb9af7",
            syntax2: "#9ece6a", syntax3: "#7dcfff", comment: "#565f89"
        )),
        CodTheme(name: "Catppuccin Mocha", appearance: "dark", palette: CodThemePalette(
            bg: "#1e1e2e", fg: "#cdd6f4", accent: "#89b4fa", surface: "#181825", syntax: "#cba6f7",
            syntax2: "#a6e3a1", syntax3: "#89b4fa", comment: "#6c7086"
        )),
        CodTheme(name: "GitHub Dark", appearance: "dark", palette: CodThemePalette(
            bg: "#0d1117", fg: "#c9d1d9", accent: "#58a6ff", surface: "#161b22", syntax: "#d2a8ff",
            syntax2: "#a5d6ff", syntax3: "#79c0ff", comment: "#8b949e"
        )),
        CodTheme(name: "Night Owl", appearance: "dark", palette: CodThemePalette(
            bg: "#011627", fg: "#d6deeb", accent: "#82aaff", surface: "#0b2942", syntax: "#c792ea",
            syntax2: "#ecc48d", syntax3: "#82aaff", comment: "#637777"
        )),
        CodTheme(name: "Solarized Dark", appearance: "dark", palette: CodThemePalette(
            bg: "#002b36", fg: "#839496", accent: "#268bd2", surface: "#073642", syntax: "#859900",
            syntax2: "#2aa198", syntax3: "#268bd2", comment: "#586e75"
        )),
        CodTheme(name: "Ayu Dark", appearance: "dark", palette: CodThemePalette(
            bg: "#0f1419", fg: "#e6e1cf", accent: "#f29668", surface: "#141920", syntax: "#e6b450",
            syntax2: "#aad94c", syntax3: "#39bae6", comment: "#5c6773"
        )),
        CodTheme(name: "Material Palenight", appearance: "dark", palette: CodThemePalette(
            bg: "#292d3e", fg: "#babed8", accent: "#c792ea", surface: "#202331", syntax: "#c792ea",
            syntax2: "#89ddff", syntax3: "#a6adc8", comment: "#676e95"
        )),
        CodTheme(name: "SynthWave '84", appearance: "dark", palette: CodThemePalette(
            bg: "#262335", fg: "#e0e0e0", accent: "#ff7b29", surface: "#2f2b40", syntax: "#f92aad",
            syntax2: "#f6f080", syntax3: "#36d6e7", comment: "#495495"
        )),
        CodTheme(name: "Monokai Dimmed", appearance: "dark", palette: CodThemePalette(
            bg: "#1e1e1e", fg: "#c0c0c0", accent: "#9cc46c", surface: "#252525", syntax: "#c7444a",
            syntax2: "#9cc46c", syntax3: "#608ec4", comment: "#5a5a5a"
        )),
        CodTheme(name: "Tokyo Night Storm", appearance: "dark", palette: CodThemePalette(
            bg: "#24283b", fg: "#c0caf5", accent: "#7dcfff", surface: "#1f2335", syntax: "#bb9af7",
            syntax2: "#9ece6a", syntax3: "#7dcfff", comment: "#565f89"
        )),
        CodTheme(name: "Catppuccin Macchiato", appearance: "dark", palette: CodThemePalette(
            bg: "#24273a", fg: "#cad3f5", accent: "#8aadf4", surface: "#1e2030", syntax: "#c6a0f6",
            syntax2: "#a6e3a1", syntax3: "#8aadf4", comment: "#6c7086"
        )),
        CodTheme(name: "One Monokai", appearance: "dark", palette: CodThemePalette(
            bg: "#2c292d", fg: "#e2e2e2", accent: "#e5b567", surface: "#333033", syntax: "#b4d273",
            syntax2: "#e5b567", syntax3: "#6c99bb", comment: "#5c5c5c"
        )),
        CodTheme(name: "Everforest Dark", appearance: "dark", palette: CodThemePalette(
            bg: "#2d353b", fg: "#d3c6aa", accent: "#a7c080", surface: "#333c43", syntax: "#e69875",
            syntax2: "#a7c080", syntax3: "#d3c6aa", comment: "#7a8478"
        )),
        CodTheme(name: "Rosé Pine", appearance: "dark", palette: CodThemePalette(
            bg: "#191724", fg: "#e0def4", accent: "#c4a7e7", surface: "#1f1d2e", syntax: "#ebbcba",
            syntax2: "#9ccfd8", syntax3: "#c4a7e7", comment: "#6e6a86"
        )),
        CodTheme(name: "Gruvbox Dark", appearance: "dark", palette: CodThemePalette(
            bg: "#282828", fg: "#ebdbb2", accent: "#d79921", surface: "#3c3836", syntax: "#8ec07c",
            syntax2: "#b8bb26", syntax3: "#83a598", comment: "#928374"
        )),
        CodTheme(name: "Chrome DevTools Dark", appearance: "dark", palette: CodThemePalette(
            bg: "#1e1e1e", fg: "#cccccc", accent: "#569cd6", surface: "#252526", syntax: "#ce9178",
            syntax2: "#569cd6", syntax3: "#4ec9b0", comment: "#6a9955"
        )),

        CodTheme(name: "Light+", appearance: "light", palette: CodThemePalette(
            bg: "#ffffff", fg: "#1e1e1e", accent: "#007acc", surface: "#f3f3f3", syntax: "#0000ff",
            syntax2: "#a31515", syntax3: "#267f99", comment: "#008000"
        )),
        CodTheme(name: "GitHub Light", appearance: "light", palette: CodThemePalette(
            bg: "#ffffff", fg: "#24292f", accent: "#0969da", surface: "#f6f8fa", syntax: "#d73a49",
            syntax2: "#032f62", syntax3: "#005cc5", comment: "#6a737d"
        )),
        CodTheme(name: "Solarized Light", appearance: "light", palette: CodThemePalette(
            bg: "#fdf6e3", fg: "#657b83", accent: "#268bd2", surface: "#eee8d5", syntax: "#859900",
            syntax2: "#2aa198", syntax3: "#268bd2", comment: "#93a1a1"
        )),
        CodTheme(name: "Catppuccin Latte", appearance: "light", palette: CodThemePalette(
            bg: "#eff1f5", fg: "#4c4f69", accent: "#1e66f5", surface: "#e6e9ef", syntax: "#d20f39",
            syntax2: "#40a02b", syntax3: "#1e66f5", comment: "#9ca0b0"
        )),
        CodTheme(name: "Tokyo Night Day", appearance: "light", palette: CodThemePalette(
            bg: "#e1e2e7", fg: "#3760bf", accent: "#2e7de9", surface: "#d4d5db", syntax: "#8c4351",
            syntax2: "#485e30", syntax3: "#34548a", comment: "#8b8fa4"
        )),
        CodTheme(name: "Ayu Light", appearance: "light", palette: CodThemePalette(
            bg: "#fafafa", fg: "#5c6166", accent: "#f07171", surface: "#f0f0f0", syntax: "#f07171",
            syntax2: "#86b300", syntax3: "#36a3d9", comment: "#787b80"
        )),
    ]
}
