import SwiftUI

public struct Theme {
    // MARK: - Brand Colors
    public static let main = Color(hex: "#e7dccd")     // ベージュ（背景など）
    public static let sub = Color(hex: "#7ca18d")      // グリーン（強調色）
    public static let dark = Color(hex: "#4a4a4a")     // ダークグレー（テキスト）
    public static let accent = Color(hex: "#eaae79")   // サンドオレンジ（アクセント）

    // 追加：警告/注目（赤系が無いので、ブランドに馴染む“赤寄りテラコッタ”を追加）
    // ※ここは後でお好みの赤に差し替え可
    public static let warning = Color(hex: "#d26a5c")  // 朱寄りの赤（UIの注意・未確認などに使用）

    // MARK: - Semantic Colors
    public struct SemanticColor {
        public let success: Color
        public let warning: Color
        public let text: Color
        public let textSubtle: Color
        public let card: Color

        public init(
            success: Color = Theme.sub,
            warning: Color = Theme.warning,
            text: Color = Theme.dark,
            textSubtle: Color = Theme.dark.opacity(0.65),
            card: Color = Color.white.opacity(0.92)
        ) {
            self.success = success
            self.warning = warning
            self.text = text
            self.textSubtle = textSubtle
            self.card = card
        }
    }

    /// computed にして並行性/Sendable 周りの警告を避ける
    public static var semanticColor: SemanticColor { SemanticColor() }

    // MARK: - Gradients
    /// メイン背景（白→ベージュ）
    public static let gradientMain = LinearGradient(
        colors: [
            Color.white,
            Theme.main.opacity(0.92)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// カード背景
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

// MARK: - HEXカラー拡張（Dynamic Color対応）
public extension Color {
    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hexString.count {
        case 3:
            (a, r, g, b) = (255,
                            (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255,
                            int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self = Color(UIColor(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        ))
    }
}
