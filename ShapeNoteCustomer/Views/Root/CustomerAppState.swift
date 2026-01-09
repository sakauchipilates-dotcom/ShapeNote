import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class CustomerAppState: ObservableObject {

    // MARK: - Published (UI State)

    @Published private(set) var isLoggedIn: Bool = false
    @Published var needsLegalConsent: Bool = false
    @Published private(set) var subscriptionState: SubscriptionState = .free

    // ✅ 削除申請中ガード（A案：申請後ログイン不可を固定）
    @Published private(set) var isDeletionRequested: Bool = false
    @Published private(set) var deletionGuardMessage: String? = nil

    // MARK: - Firestore (lazy)

    /// ✅ Firestore 初期化は遅延（起動直後のクラッシュ/白画面回避）
    private lazy var db = Firestore.firestore()

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

    /// ✅ 削除申請ローカルキャッシュ（最重要：即ガード）
    private enum DeletionCache {
        static let requestedKey = "ShapeNote.deletion.requested.v1"
        static let requestedAtKey = "ShapeNote.deletion.requestedAt.v1"
    }

    // MARK: - Init

    init() {
        // 1) まずローカルキャッシュで UI を即安定
        loadSubscriptionCache()
        loadDeletionCache()

        // 2) Auth 状態から起動分岐
        if let user = Auth.auth().currentUser {
            print("🔁 起動時のFirebaseAuthユーザー（顧客）: \(user.email ?? "nil")")

            // ✅ ローカルで申請済みなら、絶対にログイン状態にしない（揺れ防止）
            if isDeletionRequested {
                applyDeletionGuard(reason: "init: local deletion requested")
                Task { await forceLogout() }
                return
            }

            // 一旦ログイン扱いにして良いが、直後にリモートで申請確認を必ず行う
            isLoggedIn = true

            Task {
                await refreshDeletionRequestState() // ✅ リモート確認で補強
                if isDeletionRequested {
                    await forceLogout()
                    return
                }

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

    /// UI/ログイン画面側から呼ばれる想定
    func setLoggedIn(_ value: Bool) {
        // ✅ 申請済みなら true を受け付けない（ここが揺れ止めの要）
        if value, isDeletionRequested {
            applyDeletionGuard(reason: "setLoggedIn(true) blocked: deletion requested")
            Task { await forceLogout() }
            return
        }

        self.isLoggedIn = value
        print(value ? "✅ 顧客ログイン状態に変更" : "🚪 顧客ログアウト状態に変更")

        if value {
            Task {
                await refreshDeletionRequestState()
                if isDeletionRequested {
                    await forceLogout()
                    return
                }

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

    // MARK: - ✅ A案: Deletion Request Guard

    private func applyDeletionGuard(reason: String) {
        isLoggedIn = false
        needsLegalConsent = false
        applySubscriptionState(.free, reason: reason)
        stopSubscriptionListening()
        deletionGuardMessage = "退会申請を受け付けています。処理完了までログインできません。"
        print("🚫 deletion guard enabled: \(reason)")
    }

    private func loadDeletionCache() {
        let requested = UserDefaults.standard.bool(forKey: DeletionCache.requestedKey)
        isDeletionRequested = requested
        if requested {
            deletionGuardMessage = "退会申請を受け付けています。処理完了までログインできません。"
        }
    }

    private func saveDeletionCache(requestedAt: Date = Date()) {
        UserDefaults.standard.set(true, forKey: DeletionCache.requestedKey)
        UserDefaults.standard.set(requestedAt.timeIntervalSince1970, forKey: DeletionCache.requestedAtKey)

        isDeletionRequested = true
        deletionGuardMessage = "退会申請を受け付けています。処理完了までログインできません。"
    }

    /// ✅ 起動後 / ログイン後にサーバー側の申請有無を確認（端末変更・再インストール対策）
    func refreshDeletionRequestState() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // ローカル true なら揺れ防止のためリモート確認は不要（解除しない）
        if isDeletionRequested { return }

        do {
            let snap = try await db.collection("accountDeletionRequests").document(uid).getDocument()

            guard snap.exists else { return }

            let data = snap.data() ?? [:]
            let status = (data["status"] as? String ?? "pending").lowercased()

            // A案：pending/requested/processing はログイン不可
            if ["pending", "requested", "processing"].contains(status) {
                saveDeletionCache()
                print("🚫 deletion requested (remote) status=\(status) => guard enabled")
            }

            // 審査向けは解除ロジックを入れない（揺れ防止）
            // ※もし運用で解除が必要なら "rejected/cancelled" の時だけ false に戻す処理を別途追加

        } catch {
            // 通信失敗時は解除しない（揺れ防止）
            print("⚠️ refreshDeletionRequestState failed: \(error.localizedDescription)")
        }
    }

    /// ✅ 退会申請（A案）
    /// 挙動: Firestoreに申請記録 → ローカルに申請フラグ保存 → 強制ログアウト
    func requestAccountDeletion() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "CustomerAppState",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "ログイン情報が取得できません。再ログインしてください。"]
            )
        }

        let uid = user.uid
        let email = user.email ?? ""

        do {
            try await db.collection("accountDeletionRequests").document(uid).setData([
                "uid": uid,
                "email": email,
                "status": "pending",
                "requestedAt": FieldValue.serverTimestamp(),
                "clientRequestedAt": Date().timeIntervalSince1970
            ], merge: true)

            print("📝 account deletion request created/updated: \(uid)")
        } catch {
            print("❌ requestAccountDeletion Firestore error: \(error.localizedDescription)")
            throw error
        }

        // ローカル即ガード（最重要）
        saveDeletionCache()

        // 申請後ログイン不可を固定するため、即ログアウト
        await forceLogout()
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
        // print("ℹ️ applySubscriptionState: \(reason)")
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
            // ネットワーク不調時はローカル採用（閉じ込め防止）
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

        // ✅ 申請済みの場合、ログアウト後もガード表示を維持
        if isDeletionRequested {
            applyDeletionGuard(reason: "forceLogout: deletion requested")
            return
        }

        isLoggedIn = false
        needsLegalConsent = false
        applySubscriptionState(.free, reason: "forceLogout")
        stopSubscriptionListening()
    }
}
