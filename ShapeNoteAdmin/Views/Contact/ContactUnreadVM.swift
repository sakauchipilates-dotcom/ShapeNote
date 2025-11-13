import Foundation
import FirebaseFirestore
import Combine  // 🔹← これが必要！

final class ContactUnreadVM: ObservableObject {
    @Published var unreadCount: Int = 0
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    init() {
        startListening()
    }

    deinit {
        stopListening()
    }

    /// Firestoreリアルタイム監視：未返信件数をカウント
    private func startListening() {
        listener = db.collection("contacts")
            .whereField("status", isEqualTo: "未読") // または "未返信" に合わせて変更
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("⚠️ 未返信カウント監視エラー: \(error.localizedDescription)")
                    return
                }
                DispatchQueue.main.async {  // 🔹UI更新はメインスレッドで
                    self.unreadCount = snapshot?.documents.count ?? 0
                }
            }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }
}
