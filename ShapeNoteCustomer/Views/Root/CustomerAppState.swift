import Foundation
import FirebaseAuth
import Combine

@MainActor
final class CustomerAppState: ObservableObject {
    @Published var isLoggedIn: Bool = false

    init() {
        // ✅ 起動時に Firebase のログイン状態をチェック
        if let user = Auth.auth().currentUser {
            print("🔁 起動時のFirebaseAuthユーザー（顧客）: \(user.email ?? "nil")")
            isLoggedIn = true
        } else {
            print("⚠️ 顧客アプリ：currentUser が nil（再ログインが必要）")
            isLoggedIn = false
        }
    }

    /// ログイン・ログアウト時に状態を更新
    func setLoggedIn(_ value: Bool) {
        Task { @MainActor in
            self.isLoggedIn = value
            print(value ? "✅ 顧客ログイン状態に変更" : "🚪 顧客ログアウト状態に変更")
        }
    }
}
