import Foundation

struct CodThemePalette: Codable, Equatable {
    var bg: String
    var fg: String
    var accent: String
    var surface: String
    var syntax: String
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
            bg: "#000000", fg: "#ffffff", accent: "#0070f3", surface: "#0e0e0e", syntax: "#ff7b72"
        )),
        CodTheme(name: "Dark+", appearance: "dark", palette: CodThemePalette(
            bg: "#1e1e1e", fg: "#d4d4d4", accent: "#569cd6", surface: "#252526", syntax: "#569cd6"
        )),
        CodTheme(name: "Monokai", appearance: "dark", palette: CodThemePalette(
            bg: "#272822", fg: "#f8f8f2", accent: "#a6e22e", surface: "#2c2d2a", syntax: "#f92672"
        )),
        CodTheme(name: "Dracula", appearance: "dark", palette: CodThemePalette(
            bg: "#282a36", fg: "#f8f8f2", accent: "#bd93f9", surface: "#21222c", syntax: "#ff79c6"
        )),
        CodTheme(name: "Nord", appearance: "dark", palette: CodThemePalette(
            bg: "#2e3440", fg: "#eceff4", accent: "#88c0d0", surface: "#3b4252", syntax: "#81a1c1"
        )),
        CodTheme(name: "One Dark Pro", appearance: "dark", palette: CodThemePalette(
            bg: "#282c34", fg: "#abb2bf", accent: "#61afef", surface: "#2c313a", syntax: "#c678dd"
        )),
        CodTheme(name: "Tokyo Night", appearance: "dark", palette: CodThemePalette(
            bg: "#1a1b26", fg: "#c0caf5", accent: "#7aa2f7", surface: "#24283b", syntax: "#bb9af7"
        )),
        CodTheme(name: "Catppuccin Mocha", appearance: "dark", palette: CodThemePalette(
            bg: "#1e1e2e", fg: "#cdd6f4", accent: "#89b4fa", surface: "#181825", syntax: "#cba6f7"
        )),
        CodTheme(name: "GitHub Dark", appearance: "dark", palette: CodThemePalette(
            bg: "#0d1117", fg: "#c9d1d9", accent: "#58a6ff", surface: "#161b22", syntax: "#79c0ff"
        )),
        CodTheme(name: "Night Owl", appearance: "dark", palette: CodThemePalette(
            bg: "#011627", fg: "#d6deeb", accent: "#82aaff", surface: "#0b2942", syntax: "#c792ea"
        )),
        CodTheme(name: "Solarized Dark", appearance: "dark", palette: CodThemePalette(
            bg: "#002b36", fg: "#839496", accent: "#268bd2", surface: "#073642", syntax: "#859900"
        )),
        CodTheme(name: "Ayu Dark", appearance: "dark", palette: CodThemePalette(
            bg: "#0f1419", fg: "#e6e1cf", accent: "#f29668", surface: "#141920", syntax: "#e6b450"
        )),
        CodTheme(name: "Material Palenight", appearance: "dark", palette: CodThemePalette(
            bg: "#292d3e", fg: "#babed8", accent: "#c792ea", surface: "#202331", syntax: "#89ddff"
        )),
        CodTheme(name: "SynthWave '84", appearance: "dark", palette: CodThemePalette(
            bg: "#262335", fg: "#e0e0e0", accent: "#ff7b29", surface: "#2f2b40", syntax: "#f92aad"
        )),
        CodTheme(name: "Monokai Dimmed", appearance: "dark", palette: CodThemePalette(
            bg: "#1e1e1e", fg: "#c0c0c0", accent: "#9cc46c", surface: "#252525", syntax: "#c7444a"
        )),
        CodTheme(name: "Tokyo Night Storm", appearance: "dark", palette: CodThemePalette(
            bg: "#24283b", fg: "#c0caf5", accent: "#7dcfff", surface: "#1f2335", syntax: "#bb9af7"
        )),
        CodTheme(name: "Catppuccin Macchiato", appearance: "dark", palette: CodThemePalette(
            bg: "#24273a", fg: "#cad3f5", accent: "#8aadf4", surface: "#1e2030", syntax: "#c6a0f6"
        )),
        CodTheme(name: "One Monokai", appearance: "dark", palette: CodThemePalette(
            bg: "#2c292d", fg: "#e2e2e2", accent: "#e5b567", surface: "#333033", syntax: "#b4d273"
        )),
        CodTheme(name: "Everforest Dark", appearance: "dark", palette: CodThemePalette(
            bg: "#2d353b", fg: "#d3c6aa", accent: "#a7c080", surface: "#333c43", syntax: "#e69875"
        )),
        CodTheme(name: "Rosé Pine", appearance: "dark", palette: CodThemePalette(
            bg: "#191724", fg: "#e0def4", accent: "#c4a7e7", surface: "#1f1d2e", syntax: "#ebbcba"
        )),
        CodTheme(name: "Gruvbox Dark", appearance: "dark", palette: CodThemePalette(
            bg: "#282828", fg: "#ebdbb2", accent: "#d79921", surface: "#3c3836", syntax: "#8ec07c"
        )),
        CodTheme(name: "Chrome DevTools Dark", appearance: "dark", palette: CodThemePalette(
            bg: "#1e1e1e", fg: "#cccccc", accent: "#569cd6", surface: "#252526", syntax: "#ce9178"
        )),

        CodTheme(name: "Light+", appearance: "light", palette: CodThemePalette(
            bg: "#ffffff", fg: "#1e1e1e", accent: "#007acc", surface: "#f3f3f3", syntax: "#795e26"
        )),
        CodTheme(name: "GitHub Light", appearance: "light", palette: CodThemePalette(
            bg: "#ffffff", fg: "#24292f", accent: "#0969da", surface: "#f6f8fa", syntax: "#cf222e"
        )),
        CodTheme(name: "Solarized Light", appearance: "light", palette: CodThemePalette(
            bg: "#fdf6e3", fg: "#657b83", accent: "#268bd2", surface: "#eee8d5", syntax: "#859900"
        )),
        CodTheme(name: "Catppuccin Latte", appearance: "light", palette: CodThemePalette(
            bg: "#eff1f5", fg: "#4c4f69", accent: "#1e66f5", surface: "#e6e9ef", syntax: "#d20f39"
        )),
        CodTheme(name: "Tokyo Night Day", appearance: "light", palette: CodThemePalette(
            bg: "#e1e2e7", fg: "#3760bf", accent: "#2e7de9", surface: "#d4d5db", syntax: "#8c4351"
        )),
        CodTheme(name: "Ayu Light", appearance: "light", palette: CodThemePalette(
            bg: "#fafafa", fg: "#5c6166", accent: "#f07171", surface: "#f0f0f0", syntax: "#39bae6"
        )),
    ]
}
