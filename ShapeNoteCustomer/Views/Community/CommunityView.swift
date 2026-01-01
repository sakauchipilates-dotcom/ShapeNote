import SwiftUI
import ShapeCore

struct CommunityView: View {

    // ダミー：近日追加予定の入口
    struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
    }

    // ダミー：最新（お知らせ/投稿）表示用
    struct FeedItem: Identifiable {
        let id = UUID()
        let title: String
        let body: String
        let date: Date
        let typeLabel: String
        let typeIcon: String
    }

    private let features: [Feature] = [
        .init(icon: "chart.line.uptrend.xyaxis", title: "記録の共有", subtitle: "継続のコツや変化をシェア"),
        .init(icon: "calendar.badge.clock", title: "イベント告知", subtitle: "グループ/キャンペーンの案内"),
        .init(icon: "sparkles", title: "おすすめ投稿", subtitle: "運動・食事・セルフケア"),
        .init(icon: "megaphone.fill", title: "スタジオからのお知らせ", subtitle: "休講/更新情報など")
    ]

    private let feed: [FeedItem] = [
        .init(
            title: "1月の営業日について",
            body: "営業日・休業日の案内をここに表示します（ダミー）。",
            date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            typeLabel: "お知らせ",
            typeIcon: "megaphone.fill"
        ),
        .init(
            title: "おすすめセルフケアを追加しました",
            body: "動画・記事などのおすすめをここに表示します（ダミー）。",
            date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            typeLabel: "おすすめ",
            typeIcon: "sparkles"
        ),
        .init(
            title: "イベント準備中です",
            body: "イベント情報をここに表示します（ダミー）。",
            date: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
            typeLabel: "イベント",
            typeIcon: "calendar.badge.clock"
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    heroCard

                    quickActionsCard

                    feedCard

                    Spacer(minLength: 12)
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("コミュニティ")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }

    // MARK: - Hero
    private var heroCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(Theme.sub.opacity(0.85))

            Text("コミュニティ")
                .font(.title3.bold())
                .foregroundColor(Theme.dark)

            Text("スタジオからの最新情報やおすすめをお届けします。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)

                Text("現在は準備中（近日公開）")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.05)))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Quick actions
    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("近日追加予定")
                .font(.headline)
                .foregroundColor(Theme.dark)

            VStack(spacing: 10) {
                ForEach(features) { f in
                    NavigationLink {
                        CommunityPlaceholderDetailView(
                            title: f.title,
                            subtitle: f.subtitle
                        )
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.sub.opacity(0.15))
                                    .frame(width: 40, height: 40)

                                Image(systemName: f.icon)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Theme.sub)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Theme.dark)

                                Text(f.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Feed
    private var feedCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Text("最新")
                    .font(.headline)
                    .foregroundColor(Theme.dark)
                Spacer()
                Text("ダミー表示")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.05)))
            }

            VStack(spacing: 10) {
                ForEach(feed) { item in
                    NavigationLink {
                        CommunityFeedDetailView(item: item)
                    } label: {
                        feedRow(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
        )
        .padding(.horizontal, 16)
    }

    private func feedRow(_ item: FeedItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.sub.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: item.typeIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.sub)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.typeLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.05)))

                    Spacer()

                    Text(formatDate(item.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.dark)

                Text(item.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.top, 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/M/d"
        return f.string(from: date)
    }
}

// MARK: - Placeholder Detail（近日追加予定の各入口）
private struct CommunityPlaceholderDetailView: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.8))

                Text(title)
                    .font(.title3.bold())

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("この機能は準備中です。")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.top, 40)
            .padding(.horizontal, 16)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Feed Detail（最新の詳細）
private struct CommunityFeedDetailView: View {
    let item: CommunityView.FeedItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                HStack(spacing: 10) {
                    Image(systemName: item.typeIcon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.sub)

                    Text(item.typeLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formatDate(item.date))
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

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: date)
    }
}

#Preview {
    CommunityView()
}
