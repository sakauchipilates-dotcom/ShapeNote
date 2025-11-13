import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import ShapeCore

struct ChatRoomView: View {
    @StateObject private var vm: ChatRoomVM
    @State private var adminIconURL: URL?
    @State private var userIconURL: URL?
    @FocusState private var isInputFocused: Bool

    private let db = Firestore.firestore()

    init(uid: String, userName: String) {
        _vm = StateObject(wrappedValue: ChatRoomVM(uid: uid, userName: userName))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
                .onChange(of: vm.messages.count) { _ in scrollToBottom(proxy: proxy) }
                .onTapGesture { isInputFocused = false }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("メッセージを入力", text: $vm.newMessageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .lineLimit(1...4)
                    .disabled(vm.isSending)

                Button {
                    Task { await vm.sendMessage() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 22))
                        .foregroundColor(vm.newMessageText.isEmpty ? .gray : Theme.sub)
                        .rotationEffect(.degrees(45))
                }
                .disabled(vm.newMessageText.isEmpty || vm.isSending)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle("管理者とのチャット")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadIcons() }
    }

    // MARK: - 各メッセージ行
    private func messageRow(_ message: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.senderIsAdmin {
                Spacer()
                messageBubble(text: message.text, color: Theme.sub.opacity(0.2), iconURL: adminIconURL, alignRight: true)
            } else {
                messageBubble(text: message.text, color: Color.gray.opacity(0.2), iconURL: userIconURL, alignRight: false)
                Spacer()
            }
        }
        .padding(.horizontal, 4)
        .transition(.move(edge: message.senderIsAdmin ? .trailing : .leading))
    }

    private func messageBubble(text: String, color: Color, iconURL: URL?, alignRight: Bool) -> some View {
        VStack(alignment: alignRight ? .trailing : .leading, spacing: 4) {
            HStack(spacing: 8) {
                if !alignRight {
                    iconView(iconURL)
                }
                Text(text)
                    .padding(10)
                    .background(color)
                    .cornerRadius(10)
                if alignRight {
                    iconView(iconURL)
                }
            }
            Text(formatTimestamp(Date()))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.8, alignment: alignRight ? .trailing : .leading)
    }

    private func iconView(_ url: URL?) -> some View {
        AsyncImage(url: url) { image in
            image.resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
        } placeholder: {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.gray.opacity(0.4))
        }
    }

    // MARK: - FirestoreからアイコンURL取得
    private func loadIcons() async {
        do {
            let userDoc = try await db.collection("users").document(vm.uid).getDocument()
            if let urlString = userDoc.data()?["iconURL"] as? String,
               let url = URL(string: urlString) {
                userIconURL = url
            }

            let adminDoc = try await db.collection("admins").document("main").getDocument()
            if let urlString = adminDoc.data()?["iconURL"] as? String,
               let url = URL(string: urlString) {
                adminIconURL = url
            }
        } catch {
            print("❌ アイコン読み込みエラー: \(error.localizedDescription)")
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = vm.messages.last {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
