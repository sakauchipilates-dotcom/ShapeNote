import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import ShapeCore

struct CustomerChatListView: View {
    // MARK: - States
    @State private var chat: ChatItem?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let db = Firestore.firestore()
    private var uid: String? { Auth.auth().currentUser?.uid }

    // 管理者プロフィール（固定）
    private let adminName = "坂内（管理者）"
    private let adminIconURL = URL(string: "https://firebasestorage.googleapis.com/v0/b/shapenote-496ea.appspot.com/o/admin_uploads%2Fadmin_icon.jpg?alt=media")

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.main.ignoresSafeArea()

                if isLoading {
                    ProgressView("読み込み中…")
                        .tint(Theme.sub)
                } else if let errorMessage {
                    Text("⚠️ \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else if let chat = chat {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            NavigationLink(destination: CustomerChatRoomView(uid: chat.id ?? "")) {
                                CustomerChatRowView(
                                    adminName: adminName,
                                    adminIconURL: adminIconURL,
                                    lastText: chat.lastText,
                                    updatedAt: chat.updatedAt,
                                    adminUnread: chat.userUnread
                                )
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 12)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.sub.opacity(0.6))
                        Text("メッセージはまだありません")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("チャット一覧")
            .navigationBarTitleDisplayMode(.inline)
            .task { await fetchChat() }
            .refreshable { await fetchChat() }
        }
    }

    // MARK: - Firestore Fetch
    private func fetchChat() async {
        guard let uid else { return }
        isLoading = true
        errorMessage = nil

        do {
            let doc = try await db.collection("chats").document(uid).getDocument()
            if let data = doc.data() {
                let item = ChatItem(
                    id: uid,
                    lastText: data["lastText"] as? String ?? "",
                    lastSenderName: data["lastSenderName"] as? String ?? "",
                    lastSenderIsAdmin: data["lastSenderIsAdmin"] as? Bool ?? false,
                    updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
                    adminUnread: data["adminUnread"] as? Bool ?? false,
                    userUnread: data["userUnread"] as? Bool ?? false
                )
                await MainActor.run {
                    self.chat = item
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.chat = nil
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
