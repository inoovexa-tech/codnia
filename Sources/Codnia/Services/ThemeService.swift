import SwiftUI
import Foundation

struct ThemeColors: Equatable {
    let bgPrimary: Color
    let bgSecondary: Color
    let bgTertiary: Color
    let bgHover: Color
    let bgActive: Color
    let borderDefault: Color
    let borderLight: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let accent: Color
    let selectionBg: Color
    let lineHighlight: Color
    let syntaxKeyword: Color
    let syntaxString: Color
    let syntaxComment: Color
    let syntaxNumber: Color
    let syntaxType: Color
    let syntaxFunction: Color
    let syntaxProperty: Color
    let syntaxConstant: Color
    let syntaxOperator: Color

    init(theme: CodTheme) {
        let p = theme.palette
        let bg = Color(hex: p.bg)
        let fg = Color(hex: p.fg)
        let accent = Color(hex: p.accent)
        let surface = Color(hex: p.surface)
        let syntax = Color(hex: p.syntax)
        let isDark = theme.appearance == "dark"

        self.bgPrimary = bg
        self.bgSecondary = surface
        self.bgTertiary = Color(hex: blend(p.bg, p.surface, weight: isDark ? 0.3 : 0.2))
        self.bgHover = Color(hex: blend(p.bg, p.fg, weight: isDark ? 0.08 : 0.06))
        self.bgActive = accent.opacity(0.15)
        self.borderDefault = surface
        self.borderLight = Color(hex: blend(p.bg, p.surface, weight: isDark ? 0.5 : 0.4))
        self.textPrimary = fg
        self.textSecondary = fg.opacity(isDark ? 0.55 : 0.75)
        self.textTertiary = fg.opacity(isDark ? 0.35 : 0.55)
        self.accent = accent
        self.selectionBg = accent.opacity(0.25)
        self.lineHighlight = accent.opacity(0.05)
        self.syntaxKeyword = syntax
        self.syntaxString = p.syntax2.flatMap { Color(hex: $0) } ?? Color(hex: blend(p.syntax, p.accent, weight: isDark ? 0.6 : 0.5))
        self.syntaxComment = Color(hex: isDark ? "#9ca3af" : "#6b7280")
        self.syntaxNumber = p.syntax5.flatMap { Color(hex: $0) } ?? p.syntax3.flatMap { Color(hex: $0) } ?? accent
        self.syntaxType = p.syntax3.flatMap { Color(hex: $0) } ?? Color(hex: blend(p.syntax, p.accent, weight: 0.5))
        self.syntaxFunction = p.syntax4.flatMap { Color(hex: $0) } ?? p.syntax2.flatMap { Color(hex: $0) } ?? syntax
        self.syntaxProperty = p.syntax6.flatMap { Color(hex: $0) } ?? p.syntax2.flatMap { Color(hex: $0) } ?? Color(hex: blend(p.syntax, p.accent, weight: isDark ? 0.3 : 0.25))
        self.syntaxConstant = accent
        self.syntaxOperator = fg.opacity(isDark ? 0.7 : 0.85)
    }

    static func == (lhs: ThemeColors, rhs: ThemeColors) -> Bool {
        lhs.bgPrimary == rhs.bgPrimary && lhs.textPrimary == rhs.textPrimary
    }
}

final class ThemeManager: ObservableObject, @unchecked Sendable {
    @Published var theme: CodTheme
    @Published var colors: ThemeColors

    static let shared = ThemeManager()

    private init() {
        let defaultTheme = CodTheme.builtin[0]
        self.theme = defaultTheme
        self.colors = ThemeColors(theme: defaultTheme)
    }

    func apply(_ name: String) {
        guard let t = CodTheme.builtin.first(where: { $0.name == name })
                ?? loadCustom(name) else { return }
        theme = t
        colors = ThemeColors(theme: t)
    }

    func applyCustom(_ t: CodTheme) {
        theme = t
        colors = ThemeColors(theme: t)
    }

    var allThemes: [CodTheme] {
        CodTheme.builtin + customThemes
    }

    var customThemes: [CodTheme] = []

    func discoverCustomThemes() {
        let dir = customThemesDir()
        guard FileManager.default.fileExists(atPath: dir.path) else { return }
        customThemes = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))
            .flatMap { files in
                files.filter { $0.pathExtension == "json" }.compactMap { url in
                    guard let data = try? Data(contentsOf: url),
                          let t = try? JSONDecoder().decode(CodTheme.self, from: data) else { return nil }
                    return t
                }
            } ?? []
    }

    func saveCustomTheme(_ t: CodTheme) {
        let dir = customThemesDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(t.name).json")
        if let data = try? JSONEncoder().encode(t) {
            try? data.write(to: url, options: .atomic)
        }
        discoverCustomThemes()
    }

    private func loadCustom(_ name: String) -> CodTheme? {
        customThemes.first(where: { $0.name == name })
    }

    private func customThemesDir() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/codnia/themes")
    }
}
