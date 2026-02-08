import SwiftUI
import ShapeCore

struct CommunityView: View {

    @StateObject private var vm = CommunityVM()

    // 近日追加予定の入口（ダミー or 本番入口）
    private struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let destinationCategory: SNCommunityCategory?
    }

    /// トップのクイックアクション
    /// - 記録をシェア
    /// - ダイエットのヒント
    /// - 運動のヒント
    /// - セルフケアのヒント
    private let features: [Feature] = [
        .init(
            icon: SNCommunityCategory.share.icon,
            title: SNCommunityCategory.share.rawValue,
            subtitle: SNCommunityCategory.share.subtitle,
            destinationCategory: .share
        ),
        .init(
            icon: SNCommunityCategory.recommend.icon,
            title: "ダイエットのヒント",
            subtitle: "体重管理や食事のアイデア",
            destinationCategory: .recommend
        ),
        .init(
            icon: SNCommunityCategory.recommend.icon,
            title: "運動のヒント",
            subtitle: "トレーニングやストレッチのアイデア",
            destinationCategory: .recommend
        ),
        .init(
            icon: SNCommunityCategory.recommend.icon,
            title: "セルフケアのヒント",
            subtitle: "睡眠・リカバリー・メンタルケア",
            destinationCategory: .recommend
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    quickActionsCard

                    // コミュニティON時のみ「お知らせ」表示
                    if FeatureFlags.isCommunityEnabled {
                        latestCard
                    }

                    Spacer(minLength: 12)
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("コミュニティ")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .task {
                if FeatureFlags.isCommunityEnabled {
                    await vm.fetch()
                }
            }
            .refreshable {
                if FeatureFlags.isCommunityEnabled {
                    await vm.fetch()
                }
            }
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

            // NEW: 日々の変化をシェアする説明文
            Text("日々の変化やセルフケアのヒントをシェアしましょう。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // ステータスバッジは削除。エラーのみ表示
            if FeatureFlags.isCommunityEnabled,
               let msg = vm.errorMessage,
               !msg.isEmpty {
                Text(msg)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
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

    // MARK: - Quick actions（近日追加予定）

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("近日追加予定")
                .font(.headline)
                .foregroundColor(Theme.dark)

            VStack(spacing: 10) {
                ForEach(features) { f in
                    if FeatureFlags.isCommunityEnabled {
                        // 機能ON時：カテゴリ別一覧への入口として動く
                        NavigationLink {
                            if let category = f.destinationCategory {
                                CommunityFeedListView(
                                    category: category,
                                    items: vm.items(for: category)
                                )
                            } else {
                                CommunityPlaceholderDetailView(
                                    title: f.title,
                                    subtitle: f.subtitle
                                )
                            }
                        } label: {
                            featureRow(f)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // 機能OFF時：タップしても画面遷移しないダミーとして表示
                        featureRow(f)
                    }
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

    private func featureRow(_ f: Feature) -> some View {
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
                .opacity(FeatureFlags.isCommunityEnabled ? 1.0 : 0.4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Latest（コミュニティON時のみ表示）

    private var latestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // タイトル修正：「お知らせ（新着順3件表示）」→「お知らせ（新着）」
                Text("お知らせ（新着）")
                    .font(.headline)
                    .foregroundColor(Theme.dark)
                Spacer()
                // 右側の「ダミー表示」バッジは削除
            }

            if vm.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("読み込み中…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                let latest = vm.latest(limit: 3)

                if latest.isEmpty {
                    Text("最新のお知らせはまだありません（ダミー）")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 10) {
                        ForEach(latest) { item in
                            NavigationLink {
                                CommunityFeedDetailView(item: item)
                            } label: {
                                feedRow(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
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

    private func feedRow(_ item: SNCommunityFeedItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.sub.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: item.category.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.sub)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.category.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.05)))

                    Spacer()

                    Text(SNCommunityDateFormat.compact(item.date))
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
}

// MARK: - Placeholder Detail

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

#Preview {
    CommunityView()
}
