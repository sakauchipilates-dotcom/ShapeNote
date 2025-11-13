import SwiftUI
import FirebaseFirestore
import ShapeCore

struct AdminChatListView: View {
    @State private var chats: [ChatItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var sortOption: SortOption = .latest

    private let db = Firestore.firestore()
    private let adminName = "坂内（管理者）"

    enum SortOption: String, CaseIterable {
        case latest = "受信時間（最新順）"
        case unread = "未読メッセージ"
        case favorite = "お気に入り"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.main.ignoresSafeArea()

                if isLoading {
                    ProgressView("読み込み中…")
                        .tint(Theme.sub)
                } else if let errorMessage = errorMessage {
                    Text("⚠️ \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else if chats.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.sub.opacity(0.6))
                        Text("チャットはまだありません")
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(sortedChats()) { chat in
                                NavigationLink(destination: AdminChatRoomView(uid: chat.id ?? "", adminName: adminName)) {
                                    HStack(alignment: .top, spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Theme.sub.opacity(0.25))
                                                .frame(width: 50, height: 50)
                                            Image(systemName: chat.lastSenderIsAdmin ? "person.crop.circle.fill.badge.checkmark" : "person.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 32, height: 32)
                                                .foregroundColor(Theme.sub)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(chat.lastSenderName)
                                                    .font(.headline)
                                                    .foregroundColor(Theme.dark)
                                                Spacer()
                                                Text(formatDate(chat.updatedAt))
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            Text(chat.lastText)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }

                                        if chat.adminUnread {
                                            Circle()
                                                .fill(Theme.accent)
                                                .frame(width: 10, height: 10)
                                        }
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(Theme.cardRadius)
                                    .shadow(color: Theme.shadow, radius: 5, x: 0, y: 3)
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("チャット") // ← タイトルをナビバーに設定
            .navigationBarTitleDisplayMode(.large) // ← 統一
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("並び替え", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundColor(Theme.dark)
                    }
                }
            }
            .task { await fetchChats() }
            .refreshable { await fetchChats() }
        }
    }

    private func sortedChats() -> [ChatItem] {
        switch sortOption {
        case .latest:
            return chats.sorted { $0.updatedAt > $1.updatedAt }
        case .unread:
            return chats.sorted {
                if $0.adminUnread == $1.adminUnread {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.adminUnread && !$1.adminUnread
            }
        case .favorite:
            return chats.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    private func fetchChats() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await db.collection("chats")
                .order(by: "updatedAt", descending: true)
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}
