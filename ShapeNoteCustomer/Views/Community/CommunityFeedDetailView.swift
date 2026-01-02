import SwiftUI
import ShapeCore

struct CommunityFeedDetailView: View {
    let item: SNCommunityFeedItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                HStack(spacing: 10) {
                    Image(systemName: item.category.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.sub)

                    Text(item.category.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(SNCommunityDateFormat.jpDate(item.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(item.title)
                    .font(.title3.bold())
                    .foregroundColor(Theme.dark)

                Text(item.body)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)

                Divider().padding(.top, 8)

                Text("※この画面はダミーです。後ほど投稿・お知らせ機能に差し替えます。")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Spacer(minLength: 24)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CommunityFeedDetailView(
            item: SNCommunityFeedItem(category: .recommend, title: "タイトル", body: "本文", date: Date())
        )
    }
}
