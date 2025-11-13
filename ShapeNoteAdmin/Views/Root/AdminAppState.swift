import Foundation
import FirebaseAuth
import Combine

@MainActor
final class AdminAppState: ObservableObject {
    @Published var isLoggedIn: Bool = false

    init() {
        // ✅ 起動時に Firebase Auth のログイン状態をチェック
        if let user = Auth.auth().currentUser {
            print("🧩 起動時のFirebaseAuthユーザー（管理者）: \(user.email ?? "nil")")
            isLoggedIn = true
        } else {
            print("⚠️ 管理アプリ: currentUser が nil（再ログインが必要）")
            isLoggedIn = false
        }
    }

    /// ログイン・ログアウト時の状態更新
    func setLoggedIn(_ value: Bool) {
        Task { @MainActor in
            self.isLoggedIn = value
            print(value ? "✅ 管理者ログイン状態に変更" : "🚪 管理者ログアウト状態に変更")
        }
    }
}
