import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class CouponManagerVM: ObservableObject {
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var validUntil: Date = Date().addingTimeInterval(60 * 60 * 24 * 30)
    @Published var isCreating = false
    @Published var message: String = ""
    @Published var selectedUserId: String = ""
    @Published var distributedCoupons: [CouponData] = []

    private let db = Firestore.firestore()

    struct CouponData: Identifiable {
        let id: String
        let title: String
        let description: String
        let validUntil: Date
        let isUsed: Bool
    }

    // MARK: - クーポン発行
    func createCoupon(for userId: String) async {
        guard !title.isEmpty else {
            message = "⚠️ タイトルを入力してください"
            return
        }
        isCreating = true
        message = ""

        let coupon: [String: Any] = [
            "title": title,
            "description": description,
            "validUntil": Timestamp(date: validUntil),
            "isUsed": false,
            "createdAt": Timestamp(date: Date())
        ]

        do {
            try await db.collection("coupons").document(userId).setData(coupon, merge: true)
            message = "✅ クーポンを発行しました！"
            print("🎟 Coupon created for userId: \(userId)")
            await fetchCoupons(for: userId)
        } catch {
            message = "❌ Firestoreエラー: \(error.localizedDescription)"
        }

        isCreating = false
    }

    // MARK: - クーポン取得
    func fetchCoupons(for userId: String) async {
        guard !userId.isEmpty else { return }
        do {
            let doc = try await db.collection("coupons").document(userId).getDocument()
            if let data = doc.data() {
                let coupon = CouponData(
                    id: userId,
                    title: data["title"] as? String ?? "",
                    description: data["description"] as? String ?? "",
                    validUntil: (data["validUntil"] as? Timestamp)?.dateValue() ?? Date(),
                    isUsed: data["isUsed"] as? Bool ?? false
                )
                distributedCoupons = [coupon]
            } else {
                distributedCoupons = []
            }
        } catch {
            print("❌ fetchCoupons error: \(error.localizedDescription)")
        }
    }

    // MARK: - クーポン削除
    func deleteCoupon(for userId: String) async {
        do {
            try await db.collection("coupons").document(userId).delete()
            message = "🗑️ クーポンを削除しました"
            distributedCoupons.removeAll()
        } catch {
            message = "❌ 削除エラー: \(error.localizedDescription)"
        }
    }
}
