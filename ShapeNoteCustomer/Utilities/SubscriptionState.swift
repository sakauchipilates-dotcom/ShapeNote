import Foundation

// MARK: - Tier

enum SubscriptionTier: String, Codable {
    case free
    case premium
}

// MARK: - Source (adminGrant / apple)

enum SubscriptionSource: String, Codable, Equatable {
    case apple
    case adminGrant
    case unknown

    init(rawValueOrUnknown: String?) {
        guard let raw = rawValueOrUnknown,
              let v = SubscriptionSource(rawValue: raw) else {
            self = .unknown
            return
        }
        self = v
    }
}

// MARK: - State

struct SubscriptionState: Codable, Equatable {

    // MARK: - Stored (Firestore: users/{uid}.subscription)

    /// "premium" / "free"
    var tier: SubscriptionTier = .free

    /// subscription.source: "apple" / "adminGrant"
    /// 無い・不正は unknown に寄せる
    var source: SubscriptionSource = .unknown

    /// subscription.startedAt
    var startedAt: Date? = nil

    /// subscription.expiresAt（premiumのときは原則必須：運用ルール）
    var expiresAt: Date? = nil

    /// subscription.updatedAt（Firestore serverTimestamp）
    var updatedAt: Date? = nil

    /// adminGrant運用メタ（appleでも入っててもOK。参照用途）
    var grantedBy: String? = nil
    var reason: String? = nil

    // MARK: - Computed (Final decision: source差を吸収)

    /// “いま” 有効な premium か（sourceに依存させない）
    /// - Safety: expiresAt が無い premium は無効扱い（課金優遇しない）
    var isPremium: Bool { isPremium(now: Date()) }

    /// テスト用に now を注入できる版
    func isPremium(now: Date) -> Bool {
        guard tier == .premium else { return false }
        guard let exp = expiresAt else { return false }   // premiumなのに期限なし => 無効（安全側）
        return exp >= now
    }

    /// UI/ガード用：最終的に効いている tier（= premium or free）
    func effectiveTier(now: Date = Date()) -> SubscriptionTier {
        isPremium(now: now) ? .premium : .free
    }

    /// 期限切れ / 不整合なら tier だけ free に落として返す（メタ情報は保持）
    /// - 目的: “落ちた瞬間” に View の判定が必ず free 側に寄る
    func normalized(now: Date = Date()) -> SubscriptionState {
        guard isPremium(now: now) else {
            var s = self
            s.tier = .free
            return s
        }
        return self
    }

    // MARK: - Convenience

    /// premiumの場合のみ期限を表示したいなどで便利
    func premiumExpiryDescription(now: Date = Date(), localeId: String = "ja_JP") -> String? {
        guard isPremium(now: now), let exp = expiresAt else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: localeId)
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy/M/d"
        return f.string(from: exp)
    }

    // MARK: - Static

    static let free = SubscriptionState(
        tier: .free,
        source: .unknown,
        startedAt: nil,
        expiresAt: nil,
        updatedAt: nil,
        grantedBy: nil,
        reason: nil
    )

    /// デバッグ用：指定期限で premium を生成（sourceも指定可）
    static func premium(
        expiresAt: Date,
        startedAt: Date? = Date(),
        updatedAt: Date? = Date(),
        source: SubscriptionSource = .unknown,
        grantedBy: String? = nil,
        reason: String? = nil
    ) -> SubscriptionState {
        SubscriptionState(
            tier: .premium,
            source: source,
            startedAt: startedAt,
            expiresAt: expiresAt,
            updatedAt: updatedAt,
            grantedBy: grantedBy,
            reason: reason
        )
    }
}
