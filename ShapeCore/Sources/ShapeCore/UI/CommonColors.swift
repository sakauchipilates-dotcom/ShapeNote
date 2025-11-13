import SwiftUI

/// アプリ全体で共通して使う色定義
extension Color {
    static let accent = Color("AccentColor") // Assetsにある共通カラー
    static let background = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemBackground)
    static let warning = Color.orange.opacity(0.9)
    static let success = Color.green.opacity(0.8)
}
