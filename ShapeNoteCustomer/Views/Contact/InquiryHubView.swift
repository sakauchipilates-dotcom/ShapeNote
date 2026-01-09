import SwiftUI
import ShapeCore

struct InquiryHubView: View {

    @EnvironmentObject private var appState: CustomerAppState
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                NavigationLink {
                    InfoContactView()
                } label: {
                    row(icon: "envelope.fill", title: "お問い合わせフォーム", subtitle: "ご質問・ご相談はこちらから")
                }

                NavigationLink {
                    ChatListView()
                } label: {
                    row(icon: "bubble.left.and.bubble.right.fill", title: "個別チャット", subtitle: "会員様向け個別チャット機能です。")
                }
            }

            Section {
                Button(role: .destructive) {
                    errorMessage = nil
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill.xmark")
                            .foregroundColor(.red)
                        Text("退会する（アカウント削除申請）")
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 6)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("お問い合わせ")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .alert("退会しますか？", isPresented: $showDeleteConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("退会する", role: .destructive) {
                Task { await requestDeletion() }
            }
        } message: {
            Text("退会申請後はログインできなくなります。")
        }
    }

    private func row(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Theme.sub)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    @MainActor
    private func requestDeletion() async {
        do {
            try await appState.requestAccountDeletion()
        } catch {
            print("❌ requestAccountDeletion error: \(error.localizedDescription)")
            errorMessage = "退会申請に失敗しました。通信環境をご確認のうえ、再度お試しください。"
        }
    }
}
