import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class CustomerAppState: ObservableObject {

    @Published var isLoggedIn: Bool = false

    /// true の間は同意画面を強制表示
    @Published var needsLegalConsent: Bool = false

    /// ✅ 無料 / プレミアム状態（アプリ全体のゲート根拠）
    @Published var subscriptionState: SubscriptionState = .free

    private let db = Firestore.firestore()
    private var subscriptionListener: ListenerRegistration?

    init() {
        if let user = Auth.auth().currentUser {
            print("🔁 起動時のFirebaseAuthユーザー（顧客）: \(user.email ?? "nil")")
            isLoggedIn = true

            Task {
                await refreshLegalConsentState()
                await refreshSubscriptionState()
                startSubscriptionListener()
            }
        } else {
            print("⚠️ 顧客アプリ：currentUser が nil（再ログインが必要）")
            isLoggedIn = false
            needsLegalConsent = false
            subscriptionState = .free
        }
    }

    deinit {
        subscriptionListener?.remove()
    }

    func setLoggedIn(_ value: Bool) {
        Task { @MainActor in
            self.isLoggedIn = value
            print(value ? "✅ 顧客ログイン状態に変更" : "🚪 顧客ログアウト状態に変更")

            if value {
                await refreshLegalConsentState()
                await refreshSubscriptionState()
                startSubscriptionListener()
            } else {
                subscriptionListener?.remove()
                subscriptionListener = nil
                self.needsLegalConsent = false
                self.subscriptionState = .free
            }
        }
    }

    // MARK: - Legal
    func refreshLegalConsentState() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            needsLegalConsent = false
            return
        }

        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            let data = snap.data() ?? [:]
            let legal = data["legal"] as? [String: Any] ?? [:]

            let acceptedPrivacy = legal["privacyVersion"] as? Int ?? 0
            let acceptedTerms   = legal["termsVersion"] as? Int ?? 0

            let requiredPrivacy = LegalDocuments.privacyPolicyVersion
            let requiredTerms   = LegalDocuments.termsVersion

            let shouldShow = (acceptedPrivacy < requiredPrivacy) || (acceptedTerms < requiredTerms)
            needsLegalConsent = shouldShow

            print("🧾 legal check: accepted P=\(acceptedPrivacy) T=\(acceptedTerms) / required P=\(requiredPrivacy) T=\(requiredTerms) => show=\(shouldShow)")

        } catch {
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

    // MARK: - Subscription
    /// ✅ Firestore から subscription 状態を取得
    func refreshSubscriptionState() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            subscriptionState = .free
            return
        }

        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            let data = snap.data() ?? [:]
            let sub = data["subscription"] as? [String: Any] ?? [:]

            let tierRaw = (sub["tier"] as? String) ?? "free"
            let tier = SubscriptionTier(rawValue: tierRaw) ?? .free

            // updatedAt は任意
            let updatedAt = (sub["updatedAt"] as? Timestamp)?.dateValue()

            subscriptionState = SubscriptionState(tier: tier, updatedAt: updatedAt)
            print("💳 subscription refreshed: tier=\(tier.rawValue)")

        } catch {
            // ネットワーク不安定時は “無料扱い” に倒す（課金誤開放を防ぐ）
            subscriptionState = .free
            print("⚠️ subscription refresh failed => treat as free. error: \(error.localizedDescription)")
        }
    }

    /// ✅ subscription の変更をリアルタイム反映（管理者側で tier を切替えた時も即反映）
    private func startSubscriptionListener() {
        subscriptionListener?.remove()
        subscriptionListener = nil

        guard let uid = Auth.auth().currentUser?.uid else { return }

        subscriptionListener = db.collection("users").document(uid).addSnapshotListener { [weak self] snap, err in
            guard let self else { return }
            if let err {
                print("⚠️ subscription listener error: \(err.localizedDescription)")
                return
            }
            let data = snap?.data() ?? [:]
            let sub = data["subscription"] as? [String: Any] ?? [:]
            let tierRaw = (sub["tier"] as? String) ?? "free"
            let tier = SubscriptionTier(rawValue: tierRaw) ?? .free
            let updatedAt = (sub["updatedAt"] as? Timestamp)?.dateValue()

            Task { @MainActor in
                self.subscriptionState = SubscriptionState(tier: tier, updatedAt: updatedAt)
            }
        }
    }

    // MARK: - Logout
    func forceLogout() async {
        do {
            try Auth.auth().signOut()
        } catch {
            print("⚠️ signOut error: \(error.localizedDescription)")
        }
        subscriptionListener?.remove()
        subscriptionListener = nil
        isLoggedIn = false
        needsLegalConsent = false
        subscriptionState = .free
    }
}
