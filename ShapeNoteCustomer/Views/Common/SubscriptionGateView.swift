import SwiftUI
import ShapeCore

/// Premium限定機能の共通ゲート
/// - adminGrant / apple どちらでも、最終的に CustomerAppState.subscriptionState が premium 判定になれば通過
/// - 画面表示中に premium -> free に落ちても、このViewが即ブロック表示へ切り替わる
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
        // ✅ “now” を明示して Missing argument を確実に回避
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
        // 画面表示中に subscriptionState が変わったら即反映
        .animation(.easeInOut(duration: 0.2), value: appState.subscriptionState.tier)
        .animation(.easeInOut(duration: 0.2), value: appState.subscriptionState.expiresAt)
        // モーダルで “戻れない” ガードにしたい場合に使う
        .interactiveDismissDisabled(!allowDismiss && !isPremiumNow)
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

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Theme.dark.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // 期限表示（あれば）
                if let exp = appState.subscriptionState.expiresAt {
                    Text("有効期限：\(formatDateJP(exp))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }

                VStack(spacing: 10) {
                    // 課金導線（将来 StoreKit / 購入画面を開く想定）
                    if let onSubscribe {
                        GlassButton(
                            title: "プレミアムにする",
                            systemImage: "crown.fill",
                            background: Theme.accent
                        ) {
                            onSubscribe()
                        }
                        .frame(maxWidth: 320)
                    }

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

                Spacer(minLength: 0)
            }
            .padding(.vertical, 24)
        }
        .navigationBarBackButtonHidden(true)
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
