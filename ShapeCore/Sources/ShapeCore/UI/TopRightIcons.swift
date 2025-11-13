import SwiftUI

/// 右上に表示する通知＆ログアウトアイコン（共通コンポーネント）
public struct TopRightIcons: View {
    public var onLogout: () -> Void
    public var onNotification: () -> Void

    public init(onLogout: @escaping () -> Void, onNotification: @escaping () -> Void) {
        self.onLogout = onLogout
        self.onNotification = onNotification
    }

    public var body: some View {
        HStack(spacing: 16) {
            // 🔔 通知アイコン
            Button(action: onNotification) {
                Image(systemName: "bell")
                    .imageScale(.large)
                    .foregroundColor(.blue)
            }

            // 🚪 ログアウトアイコン
            Button(action: onLogout) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .imageScale(.large)
                    .foregroundColor(.blue)
            }
        }
    }
}
