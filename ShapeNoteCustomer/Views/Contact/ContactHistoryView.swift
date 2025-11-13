import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ContactHistoryView: View {
    @State private var contacts: [ContactItem] = []
    @State private var isLoading = true
    @State private var listener: ListenerRegistration?
    @EnvironmentObject private var contactUnreadVM: CustomerContactUnreadVM
    
    private let db = Firestore.firestore()
    private let user = Auth.auth().currentUser
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("読み込み中…")
                    .padding(.top, 40)
            } else if contacts.isEmpty {
                Text("お問い合わせ履歴はありません。")
                    .foregroundColor(.gray)
                    .padding(.top, 80)
            } else {
                List {
                    ForEach(contacts) { contact in
                        VStack(alignment: .leading, spacing: 8) {
                            // 🔹 上段：日時＋ステータス
                            HStack {
                                Text(contact.timestampString)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(contact.status == "対応済" ? "返信済み" : "未返信")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(contact.status == "対応済" ? Color.green.opacity(0.8) : Color.orange.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }

                            // 🔹 問い合わせ本文
                            Text(contact.message)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(.vertical, 2)

                            // 🔹 管理者からの返信
                            if let reply = contact.reply, !reply.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Divider()
                                    Text("返信内容")
                                        .font(.subheadline.bold())
                                    Text(reply)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    if let repliedAt = contact.repliedAtString {
                                        Text("返信日時：\(repliedAt)")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("お問い合わせ履歴")
        .onAppear {
            startListening()
            // ✅ 履歴画面を開いた時点で未読リセット
            contactUnreadVM.unreadCount = 0
        }
        .onDisappear(perform: stopListening)
    }

    // MARK: - Firestore リスナー（リアルタイム更新）
    private func startListening() {
        guard let user = user else { return }
        listener?.remove()
        isLoading = true

        listener = db.collection("contacts")
            .whereField("email", isEqualTo: user.email ?? "")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                isLoading = false
                if let error = error {
                    print("⚠️ 問い合わせ履歴エラー: \(error.localizedDescription)")
                    return
                }

                guard let docs = snapshot?.documents else {
                    contacts = []
                    return
                }

                // ✅ Firestore上の最新データ（reply/repliedAt含む）をリアルタイム反映
                contacts = docs.compactMap { doc in
                    let d = doc.data()
                    return ContactItem(
                        id: doc.documentID,
                        name: d["name"] as? String ?? "",
                        message: d["message"] as? String ?? "",
                        status: d["status"] as? String ?? "未返信",
                        timestamp: d["timestamp"] as? Timestamp ?? Timestamp(),
                        reply: d["reply"] as? String ?? "",
                        repliedAt: d["repliedAt"] as? Timestamp
                    )
                }
            }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }
}

#Preview {
    NavigationStack {
        ContactHistoryView()
            .environmentObject(CustomerContactUnreadVM())
    }
}
