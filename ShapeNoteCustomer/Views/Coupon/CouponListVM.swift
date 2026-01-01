import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class CouponListVM: ObservableObject {

    // MARK: - Tab
    enum Tab: String, CaseIterable, Identifiable {
        case available = "未使用クーポン"
        case used = "使用済みクーポン"
        case passes = "回数券"

        var id: String { rawValue }
    }

    // MARK: - Model
    struct Coupon: Identifiable {
        let id: String
        let title: String
        let description: String
        let validUntil: Date
        let isUsed: Bool
        let createdAt: Date?
        let usedAt: Date?

        var isExpired: Bool { validUntil < Date() }
        var canUseNow: Bool { !isUsed && !isExpired }
    }

    @Published var selectedTab: Tab = .available
    @Published private(set) var allCoupons: [Coupon] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    // 使用処理用
    @Published private(set) var isUpdatingUseState: Bool = false

    private let db = Firestore.firestore()

    // MARK: - Derived lists
    var availableCoupons: [Coupon] {
        let now = Date()
        return allCoupons
            .filter { !$0.isUsed && $0.validUntil >= now }
            .sorted { lhs, rhs in
                if lhs.validUntil != rhs.validUntil { return lhs.validUntil < rhs.validUntil }
                return (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
            }
    }

    var usedCoupons: [Coupon] {
        return allCoupons
            .filter { $0.isUsed }
            .sorted { lhs, rhs in
                // usedAt があれば新しい順、それが無ければ createdAt 新しい順
                let lu = lhs.usedAt ?? .distantPast
                let ru = rhs.usedAt ?? .distantPast
                if lu != ru { return lu > ru }
                return (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
            }
    }

    // 回数券は後で実装
    var passes: [Coupon] { [] }

    var availableCount: Int { availableCoupons.count }
    var usedCount: Int { usedCoupons.count }

    // MARK: - Fetch
    func fetchCoupons() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "未ログイン状態です"
            allCoupons = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let snap = try await db.collection("coupons")
                .document(uid)
                .collection("items")
                .getDocuments()

            let items: [Coupon] = snap.documents.compactMap { doc in
                let d = doc.data()

                let title = d["title"] as? String ?? ""
                let description = d["description"] as? String ?? ""
                let isUsed = d["isUsed"] as? Bool ?? false
                let validUntil = (d["validUntil"] as? Timestamp)?.dateValue()
                let createdAt = (d["createdAt"] as? Timestamp)?.dateValue()
                let usedAt = (d["usedAt"] as? Timestamp)?.dateValue()

                guard !title.isEmpty, let validUntil else { return nil }

                return Coupon(
                    id: doc.documentID,
                    title: title,
                    description: description,
                    validUntil: validUntil,
                    isUsed: isUsed,
                    createdAt: createdAt,
                    usedAt: usedAt
                )
            }

            allCoupons = items
            isLoading = false
        } catch {
            errorMessage = "クーポン取得に失敗しました: \(error.localizedDescription)"
            allCoupons = []
            isLoading = false
        }
    }

    // MARK: - Use coupon (mark as used)
    func markCouponUsed(_ coupon: Coupon) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "未ログインです"])
        }
        guard coupon.canUseNow else {
            throw NSError(domain: "coupon", code: 400, userInfo: [NSLocalizedDescriptionKey: "このクーポンは使用できません（期限切れ/使用済み）"])
        }

        isUpdatingUseState = true
        defer { isUpdatingUseState = false }

        let ref = db.collection("coupons")
            .document(uid)
            .collection("items")
            .document(coupon.id)

        // サーバー時刻を採用（端末時計のズレ対策）
        try await ref.updateData([
            "isUsed": true,
            "usedAt": FieldValue.serverTimestamp()
        ])

        // ローカル反映（usedAtは serverTimestamp なので、確実な値は再フェッチで確定）
        if let idx = allCoupons.firstIndex(where: { $0.id == coupon.id }) {
            let current = allCoupons[idx]
            allCoupons[idx] = Coupon(
                id: current.id,
                title: current.title,
                description: current.description,
                validUntil: current.validUntil,
                isUsed: true,
                createdAt: current.createdAt,
                usedAt: Date() // 仮。次回fetchでサーバー値に置き換わる
            )
        }

        // 使った直後に「使用済み」タブへ移動して確認できるようにする
        selectedTab = .used

        // サーバーの usedAt を確定させたいので軽く再取得（最短で確実）
        await fetchCoupons()
    }
}
