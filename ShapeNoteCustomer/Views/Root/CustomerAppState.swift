import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class CustomerAppState: ObservableObject {

    @Published var isLoggedIn: Bool = false

    /// true の間は同意画面を強制表示
    @Published var needsLegalConsent: Bool = false

    /// ✅ 購読状態（Root -> 各VM/各Viewへ波及）
    @Published private(set) var subscriptionState: SubscriptionState = .free

    private let db = Firestore.firestore()

    private let subscriptionRepo: SubscriptionRepository = FirestoreSubscriptionRepository()
    private var subscriptionListener: ListenerRegistration?

    // MARK: - Subscription persistence (UserDefaults)
    private enum SubscriptionCache {
        static let key = "ShapeNote.subscriptionState.v1"
    }

    // expiresAt 到達で Free に落とすタイマー（端末側の保険）
    private var subscriptionExpiryTimer: Timer?

    init() {
        // ✅ まずローカルキャッシュを読み、画面ガードを即効かせる
        loadSubscriptionCache()

        if let user = Auth.auth().currentUser {
            print("🔁 起動時のFirebaseAuthユーザー（顧客）: \(user.email ?? "nil")")
            isLoggedIn = true

            Task {
                await refreshLegalConsentState()


                await refreshSubscriptionState()

                // ✅ リアルタイム追従
                startSubscriptionListeningIfPossible()
            }
        } else {
            print("⚠️ 顧客アプリ：currentUser が nil（再ログインが必要）")
            isLoggedIn = false
            needsLegalConsent = false

            // ログアウト状態なら安全側
            applySubscriptionState(.free, reason: "init: no currentUser")
            stopSubscriptionListening()
        }
    }

    deinit {
        // deinit は nonisolated なので @MainActor メソッドは呼ばない

        subscriptionListener?.remove()
        subscriptionListener = nil

        subscriptionExpiryTimer?.invalidate()
        subscriptionExpiryTimer = nil
    }

    // MARK: - Auth state
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
            // ネットワーク不安定時は安全側で free（課金優遇しない）
            applySubscriptionState(.free, reason: "refresh failed: \(error.localizedDescription)")
            print("⚠️ subscription refresh failed => fallback free. error: \(error.localizedDescription)")
        }
    }

    // MARK: - Subscription listening
    private func startSubscriptionListeningIfPossible() {
        guard subscriptionListener == nil else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        subscriptionListener = subscriptionRepo.listen(uid: uid) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let state):
                Task { @MainActor in
                    // Listener も apply 経由で統一
                    self.applySubscriptionState(state, reason: "listener")
                    print("🔔 subscription updated (listener) => \(self.subscriptionState.tier.rawValue)")
                }

            case .failure(let error):
                Task { @MainActor in
                    // listenerエラーはfreeへ（課金優遇しない）
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

    // MARK: - ✅ Apply subscription state (single source of truth)
    /// - Important:
    ///   - 必ず normalized してから採用（期限切れpremiumはfree扱い）
    ///   - 永続化（UserDefaults）もここで実施
    ///   - expiresAt に到達したら端末側タイマーで即 free に落とす
    private func applySubscriptionState(_ incoming: SubscriptionState, reason: String) {
        let normalized = incoming.normalized(now: Date())

        if subscriptionState != normalized {
            subscriptionState = normalized
        } else {
            // 同じでもタイマーは更新したい（expiresAt更新など）
        }

        saveSubscriptionCache(subscriptionState)
        scheduleExpiryFallbackIfNeeded(for: subscriptionState)

        // デバッグログ（必要なら残す）
        // print("🧩 applySubscriptionState reason=\(reason) => \(subscriptionState.tier.rawValue)")
    }

    // MARK: - Subscription cache
    private func loadSubscriptionCache() {
        guard let data = UserDefaults.standard.data(forKey: SubscriptionCache.key) else {
            // キャッシュ無しは free
            applySubscriptionState(.free, reason: "cache: none")
            return
        }

        do {
            let decoded = try JSONDecoder().decode(SubscriptionState.self, from: data)
            applySubscriptionState(decoded, reason: "cache: loaded")
            print("💾 subscription cache loaded => \(subscriptionState.tier.rawValue)")
        } catch {
            // 壊れてたら破棄して free
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

    // MARK: - Expiry fallback (device-side)
    private func scheduleExpiryFallbackIfNeeded(for state: SubscriptionState) {
        invalidateSubscriptionExpiryTimer()

        // 「いま」有効 premium だけタイマーを張る
        guard state.isPremium(now: Date()) else { return }
        guard let exp = state.expiresAt else { return }

        let fireInterval = max(0, exp.timeIntervalSinceNow)
        subscriptionExpiryTimer = Timer.scheduledTimer(withTimeInterval: fireInterval, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                // exp 到達時点で最終判定（念のため）
                let current = self.subscriptionState.normalized(now: Date())
                if self.subscriptionState != current {
                    self.subscriptionState = current
                    self.saveSubscriptionCache(current)
                } else if !self.subscriptionState.isPremium(now: Date()) {
                    // すでに期限切れなら free に落とす（明示）
                    self.applySubscriptionState(.free, reason: "expiry timer fired")
                } else {
                    // 理論上ここには来にくいが、安全側に倒す
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

    // MARK: - Debug helpers（StoreKit導入後は呼ばない想定）
    func debugSetPremium(days: Int = 30) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let now = Date()
        let exp = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        let state = SubscriptionState(tier: .premium, startedAt: now, expiresAt: exp)
        do {
            try await subscriptionRepo.upsert(uid: uid, state: state)
            await refreshSubscriptionState()
        } catch {
            print("⚠️ debugSetPremium failed: \(error.localizedDescription)")
        }
    }

    func debugSetFree() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let state = SubscriptionState(tier: .free, startedAt: nil, expiresAt: nil)
        do {
            try await subscriptionRepo.upsert(uid: uid, state: state)
            await refreshSubscriptionState()
        } catch {
            print("⚠️ debugSetFree failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Legal (既存)
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
