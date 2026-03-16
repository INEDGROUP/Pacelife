import SwiftUI

extension Color {
    // MARK: - Brand
    static let plGreen = Color(hex: "4CFFA0")
    static let plBlue = Color(hex: "6B8FFF")
    static let plAmber = Color(hex: "FFB347")
    static let plRed = Color(hex: "FF6B6B")

    // MARK: - Background
    static let plBg = Color(hex: "0A0A0F")
    static let plBgSecondary = Color(hex: "13131F")
    static let plBgTertiary = Color(hex: "1A1A2E")

    // MARK: - Text
    static let plTextPrimary = Color(hex: "FFFFFF")
    static let plTextSecondary = Color(white: 1, opacity: 0.55)
    static let plTextTertiary = Color(white: 1, opacity: 0.35)

    // MARK: - Border
    static let plBorder = Color(white: 1, opacity: 0.08)
    static let plBorderAccent = Color(white: 1, opacity: 0.15)

    // MARK: - Hex init
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
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255)
    }
}
