import SwiftUI
import Combine
import FirebaseFirestore
import ShapeCore

@MainActor
final class ChatRoomVM: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var newMessageText: String = ""
    @Published var isSending = false

    private let db = Firestore.firestore()
    let uid: String // ← 🔥 privateを削除して公開アクセスに変更！
    private let userName: String
    private var listener: ListenerRegistration?

    init(uid: String, userName: String) {
        self.uid = uid
        self.userName = userName
        listenMessages()
        markAsRead() // ✅ チャット画面を開いた瞬間に既読化
    }

    deinit {
        listener?.remove()
    }

    // MARK: - メッセージをリアルタイム監視
    private func listenMessages() {
        listener = db.collection("chats").document(uid)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    print("❌ メッセージ読み込みエラー: \(error.localizedDescription)")
                    return
                }

                // Firestore → ChatMessage変換
                self.messages = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    guard let text = data["text"] as? String,
                          let senderName = data["senderName"] as? String,
                          let senderIsAdmin = data["senderIsAdmin"] as? Bool,
                          let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                        return nil
                    }
                    return ChatMessage(
                        id: doc.documentID,
                        text: text,
                        senderName: senderName,
                        senderIsAdmin: senderIsAdmin,
                        timestamp: timestamp
                    )
                } ?? []
            }
    }

    // MARK: - 未読 → 既読（userUnread を false に）
    func markAsRead() {
        Task {
            do {
                try await db.collection("chats").document(uid)
                    .setData(["userUnread": false], merge: true)
                print("✅ ユーザー側既読に更新")
            } catch {
                print("❌ ユーザー既読更新エラー: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - メッセージ送信
    func sendMessage() async {
        let text = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        isSending = true
        defer { isSending = false }

        let message = ChatMessage(
            id: UUID().uuidString,
            text: text,
            senderName: userName,
            senderIsAdmin: false,
            timestamp: Date()
        )

        do {
            let chatDocRef = db.collection("chats").document(uid)

            // ✅ Firestoreへ書き込み
            try await chatDocRef.collection("messages")
                .document(message.id)
                .setData([
                    "text": message.text,
                    "senderName": message.senderName,
                    "senderIsAdmin": message.senderIsAdmin,
                    "timestamp": Timestamp(date: message.timestamp)
                ])

            // ✅ UI即時反映
            await MainActor.run {
                self.messages.append(message)
            }

            // ✅ チャット概要を更新（管理者未読ON）
            let chatItem: [String: Any] = [
                "lastText": message.text,
                "lastSenderName": userName,
                "lastSenderIsAdmin": false,
                "updatedAt": Timestamp(date: Date()),
                "adminUnread": true,
                "userUnread": false
            ]
            try await chatDocRef.setData(chatItem, merge: true)

            newMessageText = ""
            print("✅ メッセージ送信成功")
        } catch {
            print("❌ 送信エラー: \(error.localizedDescription)")
        }
    }
}
