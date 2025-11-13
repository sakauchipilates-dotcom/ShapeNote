import SwiftUI
import Combine   // ✅ ← これを追加（必須！）
import FirebaseFirestore
import FirebaseAuth

final class CustomerContactUnreadVM: ObservableObject {
    @Published var unreadCount: Int = 0

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var user: User? { Auth.auth().currentUser }

    init() {
        startListening()
    }

    func startListening() {
        guard let user = user, let email = user.email else { return }
        stopListening() // 重複防止

        listener = db.collection("contacts")
            .whereField("email", isEqualTo: email)
            .whereField("status", isEqualTo: "対応済") // 管理者から返信済み
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("⚠️ 未読監視エラー: \(error.localizedDescription)")
                    return
                }
                self.unreadCount = snapshot?.documents.count ?? 0
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        stopListening()
    }
}
