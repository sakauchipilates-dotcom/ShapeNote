import SwiftUI
import ShapeCore

struct CommunityFeedListView: View {
    let category: SNCommunityCategory
    let items: [SNCommunityFeedItem]

    var body: some View {
        List {
            Section {
                if items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("このカテゴリの投稿はまだありません（ダミー）")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10)
                } else {
                    ForEach(items) { item in
                        NavigationLink {
                            CommunityFeedDetailView(item: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {

                                HStack(spacing: 8) {
                                    Image(systemName: item.category.icon)
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(Theme.sub)

                                    Text(SNCommunityDateFormat.jpDate(item.date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.secondary.opacity(0.7))
                                }

                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Theme.dark)

                                Text(item.body)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            } header: {
                HStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .foregroundColor(Theme.sub)
                    Text(category.rawValue)
                }
            } footer: {
                Text("※この画面はダミー表示です。後ほど投稿・お知らせ機能に差し替えます。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NavigationStack {
        CommunityFeedListView(
            category: .announcement,
            items: [
                SNCommunityFeedItem(
                    category: .announcement,
                    title: "テスト",
                    body: "本文",
                    date: Date()
                )
            ]
        )
    }
}
