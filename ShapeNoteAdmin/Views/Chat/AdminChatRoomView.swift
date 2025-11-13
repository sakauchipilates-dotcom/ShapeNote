import SwiftUI
import ShapeCore

struct AdminChatRoomView: View {
    @StateObject private var vm: AdminChatRoomVM
    @FocusState private var isInputFocused: Bool

    init(uid: String, adminName: String) {
        _vm = StateObject(wrappedValue: AdminChatRoomVM(uid: uid, adminName: adminName))
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
                .onChange(of: vm.messages.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .onTapGesture {
                    isInputFocused = false
                }
            }

            Divider()

            HStack {
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
                        .foregroundColor(vm.newMessageText.isEmpty ? .gray : .blue)
                        .rotationEffect(.degrees(45))
                }
                .disabled(vm.newMessageText.isEmpty || vm.isSending)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle("チャット（管理者）")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 各メッセージ行
    private func messageRow(_ message: ChatMessage) -> some View {
        HStack {
            if message.senderIsAdmin {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .padding(10)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(10)
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.text)
                        .padding(10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                Spacer()
            }
        }
        .transition(.move(edge: message.senderIsAdmin ? .trailing : .leading))
        .animation(.easeOut(duration: 0.2), value: vm.messages.count)
    }

    // MARK: - ヘルパー
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = vm.messages.last {
            withAnimation {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        AdminChatRoomView(uid: "testUser123", adminName: "坂内（管理者）")
    }
}
