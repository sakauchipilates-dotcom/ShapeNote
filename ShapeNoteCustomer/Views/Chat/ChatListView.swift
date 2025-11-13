import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import ShapeCore

struct ChatListView: View {
    @State private var chats: [ChatItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let db = Firestore.firestore()
    private let uid = AuthHandler.shared.currentUID ?? "unknown"
    private let userName = AuthHandler.shared.currentUserName ?? "ユーザー"

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.main.ignoresSafeArea()

                if isLoading {
                    ProgressView("読み込み中…").tint(Theme.sub)
                } else if let errorMessage {
                    Text("⚠️ \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else if chats.isEmpty {
                    emptyStateView
                } else {
                    chatListView
                }
            }
            .navigationTitle("チャット一覧")
            .navigationBarTitleDisplayMode(.inline)
            .task { await fetchChats() }
            .refreshable { await fetchChats() }
        }
    }

    // MARK: - 空表示
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.6))
            Text("メッセージはまだありません")
                .foregroundColor(.gray)

            NavigationLink(destination: ChatRoomView(uid: uid, userName: userName)) {
                Label("新しいチャットを始める", systemImage: "plus.bubble")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Theme.sub.opacity(0.15))
                    .cornerRadius(Theme.cardRadius)
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - チャット一覧
    private var chatListView: some View {
        List(chats) { chat in
            NavigationLink(destination: ChatRoomView(uid: chat.id ?? uid, userName: userName)) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chat.lastSenderName)
                            .font(.headline)
                            .foregroundColor(Theme.dark)
                        Text(chat.lastText)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(formatDate(chat.updatedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.main)
    }

    // MARK: - Firestoreからチャット一覧を取得
    private func fetchChats() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await db.collection("chats")
                .whereField(FieldPath.documentID(), isEqualTo: uid)
                .getDocuments()

            let fetched = snapshot.documents.compactMap { doc -> ChatItem? in
                let data = doc.data()
                return ChatItem(
                    id: doc.documentID,
                    lastText: data["lastText"] as? String ?? "",
                    lastSenderName: data["lastSenderName"] as? String ?? "",
                    lastSenderIsAdmin: data["lastSenderIsAdmin"] as? Bool ?? false,
                    updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
                    adminUnread: data["adminUnread"] as? Bool ?? false,
                    userUnread: data["userUnread"] as? Bool ?? false
                )
            }

            await MainActor.run {
                self.chats = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    // MARK: - 日付フォーマット
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}

#Preview { ChatListView() }
