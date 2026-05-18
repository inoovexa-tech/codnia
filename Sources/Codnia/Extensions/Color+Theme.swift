import SwiftUI

// MARK: - Hex manipulation utilities

func parseHexComponents(_ hex: String) -> (r: Double, g: Double, b: Double)? {
    let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: h).scanHexInt64(&int)
    let r, g, b: Double
    switch h.count {
    case 3:
        r = Double((int >> 8) & 0xF) * 17 / 255
        g = Double((int >> 4) & 0xF) * 17 / 255
        b = Double(int & 0xF) * 17 / 255
    case 6:
        r = Double((int >> 16) & 0xFF) / 255
        g = Double((int >> 8) & 0xFF) / 255
        b = Double(int & 0xFF) / 255
    case 8:
        r = Double((int >> 16) & 0xFF) / 255
        g = Double((int >> 8) & 0xFF) / 255
        b = Double(int & 0xFF) / 255
    default:
        return nil
    }
    return (r, g, b)
}

func blend(_ hex1: String, _ hex2: String, weight: Double) -> String {
    guard let c1 = parseHexComponents(hex1), let c2 = parseHexComponents(hex2) else { return hex1 }
    let w = max(0, min(1, weight))
    let r = Int((c1.r * (1 - w) + c2.r * w) * 255)
    let g = Int((c1.g * (1 - w) + c2.g * w) * 255)
    let b = Int((c1.b * (1 - w) + c2.b * w) * 255)
    return String(format: "#%02X%02X%02X", r, g, b)
}

// MARK: - Themed dynamic colors

extension Color {
    static var bgPrimary: Color { ThemeManager.shared.colors.bgPrimary }
    static var bgSecondary: Color { ThemeManager.shared.colors.bgSecondary }
    static var bgTertiary: Color { ThemeManager.shared.colors.bgTertiary }
    static var bgHover: Color { ThemeManager.shared.colors.bgHover }
    static var bgActive: Color { ThemeManager.shared.colors.bgActive }
    static var borderDefault: Color { ThemeManager.shared.colors.borderDefault }
    static var borderLight: Color { ThemeManager.shared.colors.borderLight }
    static var textPrimary: Color { ThemeManager.shared.colors.textPrimary }
    static var textSecondary: Color { ThemeManager.shared.colors.textSecondary }
    static var textTertiary: Color { ThemeManager.shared.colors.textTertiary }
    static var accentBlue: Color { ThemeManager.shared.colors.accent }
    static var selectionBg: Color { ThemeManager.shared.colors.selectionBg }
    static var lineHighlight: Color { ThemeManager.shared.colors.lineHighlight }

    static var syntaxKeyword: Color { ThemeManager.shared.colors.syntaxKeyword }
    static var syntaxString: Color { ThemeManager.shared.colors.syntaxString }
    static var syntaxComment: Color { ThemeManager.shared.colors.syntaxComment }
    static var syntaxNumber: Color { ThemeManager.shared.colors.syntaxNumber }
    static var syntaxType: Color { ThemeManager.shared.colors.syntaxType }
    static var syntaxFunction: Color { ThemeManager.shared.colors.syntaxFunction }
    static var syntaxProperty: Color { ThemeManager.shared.colors.syntaxProperty }
    static var syntaxConstant: Color { ThemeManager.shared.colors.syntaxConstant }
    static var syntaxOperator: Color { ThemeManager.shared.colors.syntaxOperator }

    static let accentGreen = Color(hex: "#10b981")
    static let accentYellow = Color(hex: "#f59e0b")
    static let accentRed = Color(hex: "#ef4444")
    static let accentOrange = Color(hex: "#d97706")
    static let accentPurple = Color(hex: "#8b5cf6")

    static let fileRust = Color(hex: "#dea584")
    static let fileTs = Color(hex: "#3178c6")
    static let fileJs = Color(hex: "#f7df1e")
    static let fileJson = Color(hex: "#f7df1e")
    static let fileHtml = Color(hex: "#e34c26")
    static let fileCss = Color(hex: "#264de4")
    static let fileScss = Color(hex: "#cf649a")
    static let fileMd = Color(hex: "#8b949e")
    static let fileDefault = Color(hex: "#8b949e")
    static let folderYellow = Color(hex: "#e8a438")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension NSColor {
    static var bgPrimary: NSColor { NSColor(Color.bgPrimary) }
    static var bgSecondary: NSColor { NSColor(Color.bgSecondary) }
    static var bgTertiary: NSColor { NSColor(Color.bgTertiary) }
    static var textPrimary: NSColor { NSColor(Color.textPrimary) }
    static var textSecondary: NSColor { NSColor(Color.textSecondary) }
    static var accentBlue: NSColor { NSColor(Color.accentBlue) }
    static var accentOrange: NSColor { NSColor(Color.accentOrange) }
    static var borderLight: NSColor { NSColor(Color.borderLight) }
    static var textTertiary: NSColor { NSColor(Color.textTertiary) }
    static var selectionBg: NSColor { NSColor(Color.selectionBg) }
    static var syntaxKeyword: NSColor { NSColor(Color.syntaxKeyword) }
    static var syntaxString: NSColor { NSColor(Color.syntaxString) }
    static var syntaxComment: NSColor { NSColor(Color.syntaxComment) }
    static var syntaxNumber: NSColor { NSColor(Color.syntaxNumber) }
    static var syntaxType: NSColor { NSColor(Color.syntaxType) }
    static var syntaxFunction: NSColor { NSColor(Color.syntaxFunction) }
    static var syntaxProperty: NSColor { NSColor(Color.syntaxProperty) }
    static var syntaxConstant: NSColor { NSColor(Color.syntaxConstant) }
    static var syntaxOperator: NSColor { NSColor(Color.syntaxOperator) }
}
