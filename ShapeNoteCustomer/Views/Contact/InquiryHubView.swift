import SwiftUI
import ShapeCore

struct InquiryHubView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    InfoContactView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(Theme.sub)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("お問い合わせフォーム")
                                .font(.headline)
                            Text("ご質問・ご相談はこちらから")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                NavigationLink {
                    ChatListView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(Theme.sub)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("個別チャット")
                                .font(.headline)
                            Text("会員様向け個別チャット機能です。")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("お問い合わせ")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NavigationStack {
        InquiryHubView()
    }
}
