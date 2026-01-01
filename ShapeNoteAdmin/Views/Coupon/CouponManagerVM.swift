import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class CouponManagerVM: ObservableObject {

    // MARK: - UI State
    @Published var selectedUserId: String = ""
    @Published var selectedUserName: String = ""   // ✅ 追加：会員詳細から渡せる
    @Published var isLoading: Bool = false
    @Published var isCreating: Bool = false
    @Published var message: String = ""
    @Published var errorMessage: String?

    // Create/Edit fields
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var validUntil: Date = Date().addingTimeInterval(60 * 60 * 24 * 30)

    // List
    @Published var coupons: [AdminCoupon] = []

    enum Filter: String, CaseIterable, Identifiable {
        case available = "未使用（有効）"
        case used = "使用済み"
        case expired = "期限切れ"
        case all = "すべて"
        var id: String { rawValue }
    }
    @Published var selectedFilter: Filter = .available

    private let db = Firestore.firestore()

    // MARK: - Model
    struct AdminCoupon: Identifiable, Equatable {
        let id: String              // couponId (docId)
        let userId: String
        var title: String
        var description: String
        var validUntil: Date
        var isUsed: Bool
        var usedAt: Date?
        var createdAt: Date?
        var updatedAt: Date?

        var isExpired: Bool { validUntil < Date() }
        var isAvailable: Bool { (!isUsed) && (!isExpired) }

        static func from(userId: String, doc: DocumentSnapshot) -> AdminCoupon? {
            let data = doc.data() ?? [:]
            let title = data["title"] as? String ?? ""
            let description = data["description"] as? String ?? ""
            let validUntil = (data["validUntil"] as? Timestamp)?.dateValue() ?? Date.distantPast
            let isUsed = data["isUsed"] as? Bool ?? false
            let usedAt = (data["usedAt"] as? Timestamp)?.dateValue()
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()

            return AdminCoupon(
                id: doc.documentID,
                userId: userId,
                title: title,
                description: description,
                validUntil: validUntil,
                isUsed: isUsed,
                usedAt: usedAt,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    // MARK: - Computed lists
    var filteredCoupons: [AdminCoupon] {
        switch selectedFilter {
        case .available:
            return coupons.filter { $0.isAvailable }
        case .used:
            return coupons.filter { $0.isUsed }
        case .expired:
            return coupons.filter { (!$0.isUsed) && $0.isExpired }
        case .all:
            return coupons
        }
    }

    // MARK: - Helpers
    private func normalizedUserId() -> String {
        selectedUserId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func itemsRef(userId: String) -> CollectionReference {
        db.collection("coupons").document(userId).collection("items")
    }

    func setUser(userId: String, userName: String = "") {
        self.selectedUserId = userId
        self.selectedUserName = userName
    }

    func clearMessages() {
        message = ""
        errorMessage = nil
    }

    // MARK: - Fetch
    func fetchCoupons() async {
        let userId = normalizedUserId()
        guard !userId.isEmpty else {
            coupons = []
            return
        }

        isLoading = true
        clearMessages()

        do {
            let snap = try await itemsRef(userId: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            coupons = snap.documents.compactMap { AdminCoupon.from(userId: userId, doc: $0) }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Create
    func createCoupon() async {
        let userId = normalizedUserId()

        guard !userId.isEmpty else {
            message = "⚠️ 対象ユーザーID（UID）を入力してください"
            return
        }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            message = "⚠️ タイトルを入力してください"
            return
        }

        isCreating = true
        clearMessages()

        let data: [String: Any] = [
            "title": title,
            "description": description,
            "validUntil": Timestamp(date: validUntil),
            "isUsed": false,
            "usedAt": FieldValue.delete(),
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "type": "coupon"
        ]

        do {
            _ = try await itemsRef(userId: userId).addDocument(data: data)
            message = "✅ クーポンを発行しました"
            await fetchCoupons()

            // 入力欄リセット
            title = ""
            description = ""
            validUntil = Date().addingTimeInterval(60 * 60 * 24 * 30)
        } catch {
            errorMessage = error.localizedDescription
            message = "❌ 発行に失敗しました"
        }

        isCreating = false
    }

    // MARK: - Update (edit)
    func updateCoupon(_ coupon: AdminCoupon, title: String, description: String, validUntil: Date) async throws {
        let userId = coupon.userId
        let ref = itemsRef(userId: userId).document(coupon.id)

        try await ref.updateData([
            "title": title,
            "description": description,
            "validUntil": Timestamp(date: validUntil),
            "updatedAt": FieldValue.serverTimestamp()
        ])

        await fetchCoupons()
    }

    // MARK: - Used / Unused（管理者は未使用に戻せる）
    func setUsed(_ coupon: AdminCoupon, to used: Bool) async throws {
        let userId = coupon.userId
        let ref = itemsRef(userId: userId).document(coupon.id)

        if used {
            try await ref.updateData([
                "isUsed": true,
                "usedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } else {
            try await ref.updateData([
                "isUsed": false,
                "usedAt": FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        }

        await fetchCoupons()
    }

    // MARK: - Delete
    func deleteCoupon(_ coupon: AdminCoupon) async throws {
        let userId = coupon.userId
        try await itemsRef(userId: userId).document(coupon.id).delete()
        await fetchCoupons()
    }

    // MARK: - Date format (yyyy年M月d日)
    static let jpDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy年M月d日"
        return f
    }()
}
