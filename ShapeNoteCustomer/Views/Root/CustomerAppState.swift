import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine
import FirebaseStorage

@MainActor
final class CustomerAppState: ObservableObject {

    // MARK: - Published (UI State)

    @Published private(set) var isLoggedIn: Bool = false
    @Published var needsLegalConsent: Bool = false
    @Published private(set) var subscriptionState: SubscriptionState = .free

    // ✅ 削除UIで「再認証が必要」を判定するためのキー
    private enum DeleteErrorUserInfoKey {
        static let requiresReauth = "requiresReauth"
    }

    // MARK: - Firestore / Storage
    private lazy var db = Firestore.firestore()
    private let storage = Storage.storage()

    // MARK: - Subscription
    private let subscriptionRepo: SubscriptionRepository = FirestoreSubscriptionRepository()
    private var subscriptionListener: ListenerRegistration?
    private var subscriptionExpiryTimer: Timer?

    // MARK: - UserDefaults Keys
    private enum SubscriptionCache {
        static let key = "ShapeNote.subscriptionState.v1"
    }

    private enum LegalCache {
        static let termsKey   = "ShapeNote.legal.termsVersion.v1"
        static let privacyKey = "ShapeNote.legal.privacyVersion.v1"
        static let acceptedAtKey = "ShapeNote.legal.acceptedAt.v1"
    }

    // MARK: - Init

    init() {
        // 1) キャッシュ読み込み（UI安定化）
        loadSubscriptionCache()

        // 2) Auth状態で分岐（削除申請・ガード類は一切使わない）
        if let user = Auth.auth().currentUser {
            print("🔁 起動時のFirebaseAuthユーザー（顧客）: \(user.email ?? "nil")")
            isLoggedIn = true

            Task {
                await refreshLegalConsentState()
                await refreshSubscriptionState()
                startSubscriptionListeningIfPossible()
            }

        } else {
            print("⚠️ 顧客アプリ：currentUser が nil（再ログインが必要）")
            isLoggedIn = false
            needsLegalConsent = false
            applySubscriptionState(.free, reason: "init: no currentUser")
            stopSubscriptionListening()
        }
    }

    deinit {
        subscriptionListener?.remove()
        subscriptionListener = nil
        subscriptionExpiryTimer?.invalidate()
        subscriptionExpiryTimer = nil
    }

    // MARK: - Public: Auth State

    func setLoggedIn(_ value: Bool) {
        self.isLoggedIn = value
        print(value ? "✅ 顧客ログイン状態に変更" : "🚪 顧客ログアウト状態に変更")

        if value {
            Task {
                await refreshLegalConsentState()
                await refreshSubscriptionState()
                startSubscriptionListeningIfPossible()
            }
        } else {
            needsLegalConsent = false
            applySubscriptionState(.free, reason: "setLoggedIn(false)")
            stopSubscriptionListening()
        }
    }

    // MARK: - ✅ Account Deletion (Apple 5.1.1(v) compliant)

    /// ✅ アプリ内で「Authユーザー削除」まで完了させる（審査対応の中心）
    /// - Firestore/Storage は best-effort（失敗しても Auth 削除を優先）
    /// - `requiresRecentLogin` の場合のみ再認証を要求する（UI側でパスワード入力）
    func deleteAccountNow(passwordForReauth: String?) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "CustomerAppState",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "ログイン情報が取得できません。再ログインしてください。"]
            )
        }

        let uid = user.uid
        let email = user.email ?? ""

        // 0) 先に監視停止（削除中の snapshot 更新・タイマー発火を避ける）
        stopSubscriptionListening()
        invalidateSubscriptionExpiryTimer()

        // 1) Firestore/Storage は best-effort で削除（落ちてもOK）
        await deleteUserDataBestEffort(uid: uid)

        // 2) ✅ Firebase Auth ユーザー削除（審査で見られる最重要ポイント）
        do {
            try await user.delete()
            print("✅ FirebaseAuth user.delete succeeded: uid=\(uid)")
        } catch {
            let ns = error as NSError

            if ns.code == AuthErrorCode.requiresRecentLogin.rawValue {
                // 再認証が必要
                guard !email.isEmpty, let pw = passwordForReauth, !pw.isEmpty else {
                    throw NSError(
                        domain: "CustomerAppState",
                        code: 403,
                        userInfo: [
                            NSLocalizedDescriptionKey: "安全のため再ログインが必要です。パスワードを入力してください。",
                            DeleteErrorUserInfoKey.requiresReauth: true
                        ]
                    )
                }

                let credential = EmailAuthProvider.credential(withEmail: email, password: pw)
                try await user.reauthenticate(with: credential)
                try await user.delete()
                print("✅ FirebaseAuth user.delete succeeded after reauth: uid=\(uid)")

            } else {
                print("❌ FirebaseAuth user.delete failed: \(ns.localizedDescription) code=\(ns.code)")
                throw error
            }
        }

        // 3) UI状態を完全リセット（Auth削除後は currentUser が nil になる想定）
        await forceLogout()
    }

    /// Firestore/Storage側の削除（best-effort）
    private func deleteUserDataBestEffort(uid: String) async {
        // Firestore: users/{uid}
        do {
            try await db.collection("users").document(uid).delete()
            print("🗑️ Firestore users/\(uid) deleted")
        } catch {
            print("⚠️ Firestore users delete failed (best-effort): \(error.localizedDescription)")
        }

        // Firestore: coupons/{uid}/items/* と coupons/{uid}
        do {
            let items = try await db.collection("coupons").document(uid).collection("items").getDocuments()
            for doc in items.documents {
                do { try await doc.reference.delete() } catch { /* best-effort */ }
            }
            do { try await db.collection("coupons").document(uid).delete() } catch { /* best-effort */ }
            print("🗑️ Firestore coupons/\(uid) deleted (best-effort)")
        } catch {
            print("⚠️ Firestore coupons delete failed (best-effort): \(error.localizedDescription)")
        }

        // Storage: user_icons/{uid}/profile.jpg（存在すれば削除）
        let iconPath = "user_icons/\(uid)/profile.jpg"
        do {
            try await storage.reference().child(iconPath).delete()
            print("🗑️ Storage \(iconPath) deleted (best-effort)")
        } catch {
            print("⚠️ Storage delete failed (best-effort): \(error.localizedDescription)")
        }
    }

    // MARK: - ✅ Subscription (public)

    func refreshSubscriptionState() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            applySubscriptionState(.free, reason: "refresh: uid nil")
            return
        }

        do {
            let fetched = try await subscriptionRepo.fetch(uid: uid)
            applySubscriptionState(fetched, reason: "refresh: fetched")
            print("💳 subscription refresh => \(subscriptionState.tier.rawValue) exp=\(subscriptionState.expiresAt?.description ?? "nil")")
        } catch {
            applySubscriptionState(.free, reason: "refresh failed: \(error.localizedDescription)")
            print("⚠️ subscription refresh failed => fallback free. error: \(error.localizedDescription)")
        }
    }

    private func startSubscriptionListeningIfPossible() {
        guard subscriptionListener == nil else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        subscriptionListener = subscriptionRepo.listen(uid: uid) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let state):
                Task { @MainActor in
                    self.applySubscriptionState(state, reason: "listener")
                    print("🔔 subscription updated (listener) => \(self.subscriptionState.tier.rawValue)")
                }

            case .failure(let error):
                Task { @MainActor in
                    self.applySubscriptionState(.free, reason: "listener error: \(error.localizedDescription)")
                    print("⚠️ subscription listener error => fallback free. \(error.localizedDescription)")
                }
            }
        }

        print("👂 subscription listener started")
    }

    private func stopSubscriptionListening() {
        subscriptionListener?.remove()
        subscriptionListener = nil
        print("👂 subscription listener stopped")
    }

    private func applySubscriptionState(_ incoming: SubscriptionState, reason: String) {
        let normalized = incoming.normalized(now: Date())

        if subscriptionState != normalized {
            subscriptionState = normalized
        }

        saveSubscriptionCache(subscriptionState)
        scheduleExpiryFallbackIfNeeded(for: subscriptionState)
    }

    private func loadSubscriptionCache() {
        guard let data = UserDefaults.standard.data(forKey: SubscriptionCache.key) else {
            applySubscriptionState(.free, reason: "cache: none")
            return
        }

        do {
            let decoded = try JSONDecoder().decode(SubscriptionState.self, from: data)
            applySubscriptionState(decoded, reason: "cache: loaded")
            print("💾 subscription cache loaded => \(subscriptionState.tier.rawValue)")
        } catch {
            UserDefaults.standard.removeObject(forKey: SubscriptionCache.key)
            applySubscriptionState(.free, reason: "cache: decode failed")
            print("⚠️ subscription cache decode failed => removed. \(error.localizedDescription)")
        }
    }

    private func saveSubscriptionCache(_ state: SubscriptionState) {
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: SubscriptionCache.key)
        } catch {
            print("⚠️ subscription cache save failed: \(error.localizedDescription)")
        }
    }

    private func scheduleExpiryFallbackIfNeeded(for state: SubscriptionState) {
        invalidateSubscriptionExpiryTimer()

        guard state.isPremium(now: Date()) else { return }
        guard let exp = state.expiresAt else { return }

        let fireInterval = max(0, exp.timeIntervalSinceNow)
        subscriptionExpiryTimer = Timer.scheduledTimer(withTimeInterval: fireInterval, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let current = self.subscriptionState.normalized(now: Date())
                if self.subscriptionState != current {
                    self.subscriptionState = current
                    self.saveSubscriptionCache(current)
                } else {
                    self.applySubscriptionState(.free, reason: "expiry timer safety")
                }
                print("⏰ subscription expiry timer fired => \(self.subscriptionState.tier.rawValue)")
            }
        }

        print("⏰ subscription expiry timer scheduled at \(exp)")
    }

    private func invalidateSubscriptionExpiryTimer() {
        subscriptionExpiryTimer?.invalidate()
        subscriptionExpiryTimer = nil
    }

    // MARK: - ✅ Legal

    private func localAcceptedTerms() -> Int {
        UserDefaults.standard.integer(forKey: LegalCache.termsKey)
    }

    private func localAcceptedPrivacy() -> Int {
        UserDefaults.standard.integer(forKey: LegalCache.privacyKey)
    }

    private func saveLocalLegalAcceptance() {
        UserDefaults.standard.set(LegalDocuments.termsVersion, forKey: LegalCache.termsKey)
        UserDefaults.standard.set(LegalDocuments.privacyPolicyVersion, forKey: LegalCache.privacyKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: LegalCache.acceptedAtKey)
    }

    func refreshLegalConsentState() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            needsLegalConsent = false
            return
        }

        let requiredPrivacy = LegalDocuments.privacyPolicyVersion
        let requiredTerms   = LegalDocuments.termsVersion

        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            let data = snap.data() ?? [:]
            let legal = data["legal"] as? [String: Any] ?? [:]

            let acceptedPrivacy = legal["privacyVersion"] as? Int ?? 0
            let acceptedTerms   = legal["termsVersion"] as? Int ?? 0

            let shouldShow = (acceptedPrivacy < requiredPrivacy) || (acceptedTerms < requiredTerms)
            needsLegalConsent = shouldShow

            print("🧾 legal check (remote): accepted P=\(acceptedPrivacy) T=\(acceptedTerms) / required P=\(requiredPrivacy) T=\(requiredTerms) => show=\(shouldShow)")
        } catch {
            let acceptedPrivacy = localAcceptedPrivacy()
            let acceptedTerms = localAcceptedTerms()
            let shouldShow = (acceptedPrivacy < requiredPrivacy) || (acceptedTerms < requiredTerms)
            needsLegalConsent = shouldShow

            print("⚠️ legal check failed (remote). fallback local. accepted P=\(acceptedPrivacy) T=\(acceptedTerms) / required P=\(requiredPrivacy) T=\(requiredTerms) => show=\(shouldShow). error: \(error.localizedDescription)")
        }
    }

    func acceptLatestLegalOptimistic() {
        saveLocalLegalAcceptance()
        needsLegalConsent = false
        print("✅ Legal同意（optimistic）: UI unlock & local saved")

        Task { await writeLatestLegalToFirestore() }
    }

    private func writeLatestLegalToFirestore() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("users").document(uid).setData([
                "legal": [
                    "privacyVersion": LegalDocuments.privacyPolicyVersion,
                    "termsVersion": LegalDocuments.termsVersion,
                    "acceptedAt": FieldValue.serverTimestamp()
                ]
            ], merge: true)

            print("✅ Legal同意をFirestoreへ保存しました")
        } catch {
            print("⚠️ Legal同意Firestore保存エラー（後でリトライでOK）: \(error.localizedDescription)")
        }
    }

    // MARK: - Logout

    func forceLogout() async {
        do {
            try Auth.auth().signOut()
        } catch {
            print("⚠️ signOut error: \(error.localizedDescription)")
        }

        isLoggedIn = false
        needsLegalConsent = false
        applySubscriptionState(.free, reason: "forceLogout")
        stopSubscriptionListening()
    }
}
