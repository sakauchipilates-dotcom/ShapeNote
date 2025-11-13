import SwiftUI
import FirebaseAuth
import FirebaseFirestore

public class AuthViewModel: ObservableObject {
    @Published public var user: User? = Auth.auth().currentUser

    public init() {
        listenAuthState()
    }

    private func listenAuthState() {
        Auth.auth().addStateDidChangeListener { _, user in
            self.user = user
        }
    }

    // MARK: - サインアウト処理
    public func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
            print("✅ ログアウト完了")
        } catch {
            print("❌ Sign out failed: \(error.localizedDescription)")
        }
    }

    // MARK: - displayIdを取得（ユーザーがログインしている場合）
    public func fetchDisplayId() async -> String? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        do {
            let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
            return doc.data()?["displayId"] as? String
        } catch {
            print("⚠️ displayId取得エラー: \(error.localizedDescription)")
            return nil
        }
    }
}
