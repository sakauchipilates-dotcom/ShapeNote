import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class CustomerAppState: ObservableObject {

    @Published var isLoggedIn: Bool = false

    /// true の間は同意画面を強制表示
    @Published var needsLegalConsent: Bool = false

    private let db = Firestore.firestore()

    init() {
        if let user = Auth.auth().currentUser {
            print("🔁 起動時のFirebaseAuthユーザー（顧客）: \(user.email ?? "nil")")
            isLoggedIn = true

            // ✅ 起動時に必ず判定（これが一番確実）
            Task { await refreshLegalConsentState() }
        } else {
            print("⚠️ 顧客アプリ：currentUser が nil（再ログインが必要）")
            isLoggedIn = false
            needsLegalConsent = false
        }
    }

    func setLoggedIn(_ value: Bool) {
        Task { @MainActor in
            self.isLoggedIn = value
            print(value ? "✅ 顧客ログイン状態に変更" : "🚪 顧客ログアウト状態に変更")

            if value {
                await refreshLegalConsentState()
            } else {
                self.needsLegalConsent = false
            }
        }
    }

    /// Firestore の同意状況を見て、必要なら同意画面を出す
    func refreshLegalConsentState() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            needsLegalConsent = false
            return
        }

        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            let data = snap.data() ?? [:]
            let legal = data["legal"] as? [String: Any] ?? [:]

            // Firestore 側（未同意なら 0 扱い）
            let acceptedPrivacy = legal["privacyVersion"] as? Int ?? 0
            let acceptedTerms   = legal["termsVersion"] as? Int ?? 0

            // アプリ側（今回ここを上げた）
            let requiredPrivacy = LegalDocuments.privacyPolicyVersion
            let requiredTerms   = LegalDocuments.termsVersion

            let shouldShow = (acceptedPrivacy < requiredPrivacy) || (acceptedTerms < requiredTerms)
            needsLegalConsent = shouldShow

            print("🧾 legal check: accepted P=\(acceptedPrivacy) T=\(acceptedTerms) / required P=\(requiredPrivacy) T=\(requiredTerms) => show=\(shouldShow)")

        } catch {
            // ネットワーク不安定時は “安全側” に倒して出す（運用上おすすめ）
            needsLegalConsent = true
            print("⚠️ legal check failed => show consent (safe). error: \(error.localizedDescription)")
        }
    }

    func acceptLatestLegal() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("users").document(uid).setData([
                "legal": [
                    "privacyVersion": LegalDocuments.privacyPolicyVersion,
                    "termsVersion": LegalDocuments.termsVersion,
                    "acceptedAt": FieldValue.serverTimestamp()
                ]
            ], merge: true)

            needsLegalConsent = false
            print("✅ Legal同意を保存しました")

        } catch {
            print("⚠️ Legal同意保存エラー: \(error.localizedDescription)")
        }
    }

    func forceLogout() async {
        do {
            try Auth.auth().signOut()
        } catch {
            print("⚠️ signOut error: \(error.localizedDescription)")
        }
        isLoggedIn = false
        needsLegalConsent = false
    }
}
