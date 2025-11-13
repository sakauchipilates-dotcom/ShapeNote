import SwiftUI
import FirebaseFirestore

struct ContactListView: View {
    // MARK: - State管理
    @State private var contacts: [ContactItem] = []
    @State private var isLoading = false
    @State private var listener: ListenerRegistration?
    @State private var selectedContact: ContactItem?
    @State private var selectedCategory: String = "all"

    @Environment(\.dismiss) private var dismiss  // 🔹 「閉じる」ボタン用

    private let db = Firestore.firestore()

    // カテゴリ選択肢
    private let categories: [(id: String, label: String)] = [
        ("all", "すべて表示"),
        ("customer", "問い合わせ"),
        ("chat", "チャット"),
        ("exercise", "エクササイズ")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: - カテゴリ切り替えPicker
                Picker("カテゴリ", selection: $selectedCategory) {
                    ForEach(categories, id: \.id) { item in
                        Text(item.label).tag(item.id)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: selectedCategory) { _ in
                    startListening()
                }

                // MARK: - 件数ラベル
                Text("件数：\(contacts.count)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 4)

                // MARK: - 通知一覧
                List {
                    if isLoading {
                        ProgressView("読み込み中…")
                    } else if contacts.isEmpty {
                        Text("現在、新しい通知はありません。")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(contacts) { contact in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(contact.name)
                                        .font(.headline)
                                    Spacer()
                                    Text(contact.status == "対応済" ? "返信済み" : "未返信")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(contact.status == "対応済" ? Color.green.opacity(0.7) : Color.orange.opacity(0.8))
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                }

                                Text(contact.message)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)

                                Text(contact.timestampString)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .padding(10)
                            .background(Color(.systemGray6)) // 🔹マテリアル風背景
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            .listRowSeparator(.hidden) // 🔹仕切り線を消す
                            .onTapGesture {
                                selectedContact = contact
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("通知一覧")
            .toolbar {
                // MARK: - 「閉じる」ボタン
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: startListening)
            .onDisappear(perform: stopListening)
            // ✅ 一覧更新をリアルタイムに反映
            .onReceive(NotificationCenter.default.publisher(for: .contactDidUpdate)) { _ in
                startListening()
            }
            // ✅ モーダル遷移
            .sheet(item: $selectedContact) { contact in
                ContactDetailView(contact: contact)
            }
        }
    }

    // MARK: - Firestore Listener
    private func startListening() {
        isLoading = true
        listener?.remove()

        var query: Query = db.collection("contacts")
            .order(by: "timestamp", descending: true)

        if selectedCategory != "all" {
            query = query.whereField("sourceApp", isEqualTo: selectedCategory)
        }

        listener = query.addSnapshotListener { snapshot, error in
            isLoading = false
            if let error = error {
                print("⚠️ 通知一覧エラー: \(error.localizedDescription)")
                return
            }
            guard let docs = snapshot?.documents else {
                contacts = []
                return
            }
            contacts = docs.compactMap { doc in
                let d = doc.data()
                return ContactItem(
                    id: doc.documentID,
                    name: d["name"] as? String ?? "匿名",
                    message: d["message"] as? String ?? "",
                    status: d["status"] as? String ?? "未読",
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
        ContactListView()
    }
}
