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

    private let features: [Feature] = [
        .init(
            icon: SNCommunityCategory.share.icon,
            title: SNCommunityCategory.share.rawValue,
            subtitle: SNCommunityCategory.share.subtitle,
            destinationCategory: .share
        ),
        .init(
            icon: SNCommunityCategory.event.icon,
            title: SNCommunityCategory.event.rawValue,
            subtitle: SNCommunityCategory.event.subtitle,
            destinationCategory: .event
        ),
        .init(
            icon: SNCommunityCategory.recommend.icon,
            title: SNCommunityCategory.recommend.rawValue,
            subtitle: SNCommunityCategory.recommend.subtitle,
            destinationCategory: .recommend
        ),
        .init(
            icon: SNCommunityCategory.announcement.icon,
            title: SNCommunityCategory.announcement.rawValue,
            subtitle: SNCommunityCategory.announcement.subtitle,
            destinationCategory: .announcement
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    quickActionsCard

                    // 初期リリースでは最新一覧は封印（コミュニティOFF時は非表示）
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
                // コミュニティ機能が有効なビルドでのみデータ取得
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

            Text("スタジオからの最新情報やおすすめをお届けします。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // 機能ON/OFFでバッジの表示を切り替え
            if FeatureFlags.isCommunityEnabled {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    Text("コミュニティ機能をご利用いただけます")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.05)))
            } else {
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
                    Text("最新の投稿はまだありません（ダミー）")
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
