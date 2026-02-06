import SwiftUI
import ShapeCore

/// Premium限定機能の共通ゲート（1定義のみ / redeclaration回避）
struct SubscriptionGateView<Content: View>: View {

    @EnvironmentObject private var appState: CustomerAppState
    @Environment(\.dismiss) private var dismiss

    private let featureName: String
    private let title: String
    private let message: String
    private let allowDismiss: Bool
    private let onClose: (() -> Void)?
    private let onSubscribe: (() -> Void)?
    private let content: () -> Content

    // ✅ 購入導線へ遷移（会員情報など）
    @State private var goToMemberInfo: Bool = false

    init(
        featureName: String,
        title: String = "プレミアム限定",
        message: String? = nil,
        allowDismiss: Bool = true,
        onClose: (() -> Void)? = nil,
        onSubscribe: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.featureName = featureName
        self.title = title
        self.message = message ?? "\(featureName) はプレミアム会員限定の機能です。"
        self.allowDismiss = allowDismiss
        self.onClose = onClose
        self.onSubscribe = onSubscribe
        self.content = content
    }

    private var isPremiumNow: Bool {
        appState.subscriptionState.isPremium(now: Date())
    }

    var body: some View {
        Group {
            if isPremiumNow {
                content()
            } else {
                gateBody
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.subscriptionState.tier)
        .animation(.easeInOut(duration: 0.2), value: appState.subscriptionState.expiresAt)
        .interactiveDismissDisabled(!allowDismiss && !isPremiumNow)
        .navigationDestination(isPresented: $goToMemberInfo) {
            // ※ 実際の購入画面
            MemberInfoView()
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Gate UI
    private var gateBody: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer(minLength: 0)

                Image(systemName: "lock.fill")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundColor(Theme.dark.opacity(0.75))

                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Theme.dark.opacity(0.88))

                // 🔽 自動更新・月額であることを明示
                Text(
                    message
                    + "\n\nShapeNote プレミアムは月額制の自動更新サブスクリプションです。"
                    + "「プレミアムにする」から購入画面へ進めます。"
                )
                .font(.subheadline)
                .foregroundColor(Theme.dark.opacity(0.72))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

                if let exp = appState.subscriptionState.expiresAt {
                    Text("有効期限：\(formatDateJP(exp))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }

                VStack(spacing: 10) {
                    // ✅ 課金導線
                    GlassButton(
                        title: "プレミアムにする",
                        systemImage: "crown.fill",
                        background: Theme.accent
                    ) {
                        if let onSubscribe {
                            onSubscribe()
                        } else {
                            goToMemberInfo = true
                        }
                    }
                    .frame(maxWidth: 320)

                    if allowDismiss {
                        GlassButton(
                            title: "閉じる",
                            systemImage: "xmark.circle.fill",
                            background: Theme.sub
                        ) {
                            close()
                        }
                        .frame(maxWidth: 320)
                    }
                }
                .padding(.top, 8)

                // ✅ ここが追加ポイント（ボタン直後）
                SubscriptionLegalInfoView()
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 24)
        }
    }

    private func close() {
        onClose?()
        dismiss()
    }

    private func formatDateJP(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy/M/d"
        return f.string(from: date)
    }
}
