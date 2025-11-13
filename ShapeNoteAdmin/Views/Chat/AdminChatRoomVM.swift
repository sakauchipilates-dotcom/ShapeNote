import SwiftUI
import Combine
import FirebaseFirestore
import ShapeCore

@MainActor
final class AdminChatRoomVM: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var newMessageText: String = ""
    @Published var isSending = false

    private let db = Firestore.firestore()
    private let uid: String
    private let adminName: String
    private var listener: ListenerRegistration?

    init(uid: String, adminName: String) {
        self.uid = uid
        self.adminName = adminName
        listenMessages()
        markAsRead() // ← 起動時に管理者側未読を解除
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
                    print("❌ 管理側読み込みエラー: \(error.localizedDescription)")
                    return
                }

                let fetched: [ChatMessage] = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    return ChatMessage(
                        id: doc.documentID,
                        text: data["text"] as? String ?? "",
                        senderName: data["senderName"] as? String ?? "",
                        senderIsAdmin: data["senderIsAdmin"] as? Bool ?? false,
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    )
                } ?? []

                Task { @MainActor in
                    self.messages = fetched
                }
            }
    }

    // MARK: - 未読 → 既読（adminUnread を false に）
    func markAsRead() {
        Task {
            do {
                try await db.collection("chats").document(uid)
                    .setData(["adminUnread": false], merge: true)
                print("✅ 管理者側既読に更新")
            } catch {
                print("❌ 管理者既読更新エラー: \(error.localizedDescription)")
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
            senderName: adminName,
            senderIsAdmin: true,
            timestamp: Date()
        )

        do {
            let chatDocRef = db.collection("chats").document(uid)

            // チャットルートが存在しなければ作成
            let chatExists = try await chatDocRef.getDocument().exists
            if !chatExists {
                try await chatDocRef.setData(["createdAt": Timestamp(date: Date())])
            }

            // Firestoreへ書き込み
            try await chatDocRef.collection("messages")
                .document(message.id)
                .setData([
                    "text": message.text,
                    "senderName": message.senderName,
                    "senderIsAdmin": message.senderIsAdmin,
                    "timestamp": Timestamp(date: message.timestamp)
                ])

            // 即UI反映
            await MainActor.run {
                self.messages.append(message)
            }

            // チャット概要更新（顧客側を未読に）
            let chatItem: [String: Any] = [
                "lastText": message.text,
                "lastSenderName": adminName,
                "lastSenderIsAdmin": true,
                "updatedAt": Timestamp(date: Date()),
                "adminUnread": false,
                "userUnread": true
            ]
            try await chatDocRef.setData(chatItem, merge: true)

            newMessageText = ""
            print("✅ 管理者送信成功")
        } catch {
            print("❌ 管理者送信エラー: \(error.localizedDescription)")
        }
    }
}
