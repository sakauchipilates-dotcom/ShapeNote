import SwiftUI
import FirebaseFirestore

// ← 公開
public final class ContactUnreadVM: ObservableObject {
    // 外部から読み取りのみ
    @Published public private(set) var unreadCount: Int = 0
    private var listener: ListenerRegistration?

    // ← 公開
    public init() {
        listenUnreadCount()
    }

    private func listenUnreadCount() {
        let db = Firestore.firestore()
        listener = db.collection("contacts")
            .whereField("status", isEqualTo: "未読")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Failed to fetch unread contacts: \(error)")
                    return
                }
                self.unreadCount = snapshot?.documents.count ?? 0
            }
    }

    deinit { listener?.remove() }
}
