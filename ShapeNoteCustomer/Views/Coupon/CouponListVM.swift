import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class CouponListVM: ObservableObject {
    @Published var coupons: [Coupon] = []
    private let db = Firestore.firestore()

    struct Coupon: Identifiable {
        let id: String
        let title: String
        let description: String
        let validUntil: Date
        let isUsed: Bool
    }

    // MARK: - Firestoreから読み取り
    func fetchCoupons() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ 未ログイン状態です")
            return
        }

        do {
            let doc = try await db.collection("coupons").document(uid).getDocument()
            if let data = doc.data() {
                let coupon = Coupon(
                    id: uid,
                    title: data["title"] as? String ?? "",
                    description: data["description"] as? String ?? "",
                    validUntil: (data["validUntil"] as? Timestamp)?.dateValue() ?? Date(),
                    isUsed: data["isUsed"] as? Bool ?? false
                )
                coupons = [coupon]
            } else {
                coupons = []
            }
        } catch {
            print("❌ クーポン取得失敗: \(error.localizedDescription)")
        }
    }
}
