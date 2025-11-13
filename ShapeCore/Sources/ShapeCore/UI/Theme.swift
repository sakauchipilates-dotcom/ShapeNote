import SwiftUI

public struct Theme {
    // MARK: - Brand Colors
    public static let main = Color(hex: "#e7dccd")     // ベージュ（背景など）
    public static let sub = Color(hex: "#7ca18d")      // グリーン（強調色）
    public static let dark = Color(hex: "#4a4a4a")     // ダークグレー（テキスト）
    public static let accent = Color(hex: "#eaae79")   // サンドオレンジ（アクセント）

    // MARK: - Gradients（追加）
    /// メイン背景用の縦グラデーション（上：白 → 下：ベージュ）
    public static let gradientMain = LinearGradient(
        colors: [
            Color.white,
            Theme.main.opacity(0.92)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// カード背景用の柔らかいグラデーション（ベージュ層）
    public static let gradientCard = LinearGradient(
        colors: [
            Theme.main.opacity(0.95),
            Theme.main.opacity(0.75)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - UI Basics
    public static let cardRadius: CGFloat = 14
    public static let shadow = Color.black.opacity(0.05)

    // MARK: - Fonts
    public static let title = Font.system(size: 20, weight: .bold)
    public static let subtitle = Font.system(size: 16, weight: .medium)
    public static let body = Font.system(size: 14)
}

// MARK: - HEXカラー拡張（Dynamic Color対応版）
public extension Color {
    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hexString.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        // ✅ Dynamic Color対応（UIKit経由）
        self = Color(UIColor(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        ))
    }
}
