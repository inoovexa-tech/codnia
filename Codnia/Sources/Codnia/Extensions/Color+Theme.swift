import SwiftUI

extension Color {
    static let bgPrimary     = Color(hex: "#000000")
    static let bgSecondary   = Color(hex: "#0e0e0e")
    static let bgTertiary    = Color(hex: "#111111")
    static let bgHover       = Color(hex: "#1a1a1a")
    static let bgActive      = Color(hex: "#1a1a1a")
    static let borderDefault = Color(hex: "#1a1a1a")
    static let borderLight   = Color(hex: "#222222")
    static let textPrimary   = Color(hex: "#ffffff")
    static let textSecondary = Color(hex: "#888888")
    static let textTertiary  = Color(hex: "#555555")
    static let accentBlue    = Color(hex: "#0070f3")
    static let accentGreen   = Color(hex: "#10b981")
    static let accentYellow  = Color(hex: "#f59e0b")
    static let accentRed     = Color(hex: "#ef4444")
    static let accentOrange  = Color(hex: "#d97706")
    static let accentPurple  = Color(hex: "#8b5cf6")
    static let fileRust      = Color(hex: "#dea584")
    static let fileTs        = Color(hex: "#3178c6")
    static let fileJs        = Color(hex: "#f7df1e")
    static let fileJson      = Color(hex: "#f7df1e")
    static let fileHtml      = Color(hex: "#e34c26")
    static let fileCss       = Color(hex: "#264de4")
    static let fileScss      = Color(hex: "#cf649a")
    static let fileMd        = Color(hex: "#8b949e")
    static let fileDefault   = Color(hex: "#8b949e")
    static let folderYellow  = Color(hex: "#e8a438")
    static let selectionBg   = Color(hex: "#264f78")
    static let lineHighlight = Color(hex: "#0a0a0a")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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
    static let bgPrimary     = NSColor(Color.bgPrimary)
    static let bgSecondary   = NSColor(Color.bgSecondary)
    static let bgTertiary    = NSColor(Color.bgTertiary)
    static let textPrimary   = NSColor(Color.textPrimary)
    static let textSecondary = NSColor(Color.textSecondary)
    static let accentBlue    = NSColor(Color.accentBlue)
    static let selectionBg   = NSColor(Color.selectionBg)
}
