import Foundation
import Combine

@MainActor
final class CommunityVM: ObservableObject {

    @Published private(set) var items: [SNCommunityFeedItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func fetch() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // 今はダミー。後で Firestore に差し替え
        let now = Date()

        items = [
            SNCommunityFeedItem(
                category: .announcement,
                title: "1月の営業日について",
                body: "営業日・休業日の案内をここに表示します（ダミー）。",
                date: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
            ),
            SNCommunityFeedItem(
                category: .recommend,
                title: "おすすめセルフケアを追加しました",
                body: "動画・記事などのおすすめをここに表示します（ダミー）。",
                date: Calendar.current.date(byAdding: .day, value: -5, to: now) ?? now
            ),
            SNCommunityFeedItem(
                category: .event,
                title: "イベント準備中です",
                body: "イベント情報をここに表示します（ダミー）。",
                date: Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now
            ),
            // share カテゴリも将来の導線として 1件入れておく（“一覧が空”になりにくい）
            SNCommunityFeedItem(
                category: .share,
                title: "記録の共有（準備中）",
                body: "継続のコツや変化のシェア機能を準備しています（ダミー）。",
                date: Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
            )
        ]
    }

    func latest(limit: Int = 3) -> [SNCommunityFeedItem] {
        Array(items.sorted { $0.date > $1.date }.prefix(limit))
    }

    func items(for category: SNCommunityCategory) -> [SNCommunityFeedItem] {
        items
            .filter { $0.category == category }
            .sorted { $0.date > $1.date }
    }
}
