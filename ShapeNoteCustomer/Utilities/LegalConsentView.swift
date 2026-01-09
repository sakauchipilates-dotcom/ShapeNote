import SwiftUI
import ShapeCore

struct LegalConsentView: View {

    let onAgree: () -> Void
    let onLogout: (() -> Void)? = nil

    private enum SheetKind: Identifiable {
        case terms
        case privacy
        var id: Int { self == .terms ? 1 : 2 }
        var title: String { self == .terms ? "利用規約" : "プライバシーポリシー" }
        var bodyText: String {
            switch self {
            case .terms: return LegalDocuments.termsText
            case .privacy: return LegalDocuments.privacyPolicyText
            }
        }
    }

    @State private var activeSheet: SheetKind? = nil

    @State private var termsReviewed: Bool = false
    @State private var privacyReviewed: Bool = false

    @State private var termsAgreed: Bool = false
    @State private var privacyAgreed: Bool = false

    // ✅ 連打防止＆処理中表示
    @State private var isSubmitting: Bool = false

    var body: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer().frame(height: 18)

                Text("利用規約・プライバシーポリシーの同意")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Theme.semanticColor.text.opacity(0.9))

                Text("サービスの利用には、以下への同意が必要です。")
                    .font(.subheadline)
                    .foregroundColor(Theme.semanticColor.textSubtle)

                contentCard
                agreeArea

                if let onLogout {
                    Button {
                        onLogout()
                    } label: {
                        Text("同意しない（ログアウト）")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Theme.semanticColor.warning.opacity(0.95))
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }

                Spacer().frame(height: 18)
            }
            .padding(.horizontal, 18)

            // ✅ 画面最前面で “今タップできてるか” 見るオーバーレイ（必要ならONに）
            // Color.clear.contentShape(Rectangle()).onTapGesture { print("🧾 [LegalConsentView] tapped on background") }
        }
        .onAppear {
            print("🧾 [LegalConsentView] appeared")
        }
        .sheet(item: $activeSheet) { kind in
            LegalDocumentSheet(
                title: kind.title,
                bodyText: kind.bodyText,
                onReviewed: {
                    switch kind {
                    case .terms: termsReviewed = true
                    case .privacy: privacyReviewed = true
                    }
                }
            )
            .presentationDetents([.large])
        }
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            headerRow(
                systemImage: "doc.text",
                title: "利用規約（アプリ内表示）",
                isReviewed: termsReviewed
            )

            GlassButton(
                title: "利用規約を確認",
                systemImage: "arrow.right.circle",
                background: (termsReviewed ? Theme.semanticColor.success : Theme.semanticColor.warning).opacity(0.22)
            ) {
                activeSheet = .terms
            }

            toggleRow(
                title: "利用規約に同意する",
                isOn: $termsAgreed,
                isEnabled: termsReviewed
            )

            Divider().opacity(0.35)

            headerRow(
                systemImage: "hand.raised.fill",
                title: "プライバシーポリシー（アプリ内表示）",
                isReviewed: privacyReviewed
            )

            GlassButton(
                title: "プライバシーポリシーを確認",
                systemImage: "arrow.right.circle",
                background: (privacyReviewed ? Theme.semanticColor.success : Theme.semanticColor.warning).opacity(0.22)
            ) {
                activeSheet = .privacy
            }

            toggleRow(
                title: "プライバシーポリシーに同意する",
                isOn: $privacyAgreed,
                isEnabled: privacyReviewed
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.semanticColor.card)
                .shadow(color: Theme.dark.opacity(0.10), radius: 10, y: 6)
        )
    }

    private func headerRow(systemImage: String, title: String, isReviewed: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundColor(Theme.sub)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Theme.semanticColor.text.opacity(0.85))
            Spacer()
            badge(isReviewed: isReviewed)
        }
    }

    private var agreeArea: some View {
        let canProceed = (termsAgreed && privacyAgreed)

        return VStack(spacing: 12) {
            Button {
                print("✅ [LegalConsentView] '同意して続行' tapped. canProceed=\(canProceed) submitting=\(isSubmitting)")
                guard canProceed else {
                    print("⚠️ [LegalConsentView] blocked: termsAgreed=\(termsAgreed) privacyAgreed=\(privacyAgreed)")
                    return
                }
                guard !isSubmitting else { return }

                // ✅ 連打防止
                isSubmitting = true

                // ✅ sheetが開いていたら閉じる（iPadで“何かが上に居て遷移しない”を潰す）
                activeSheet = nil

                // ✅ UIはここで即通す（CustomerRootView側で optimistic unlock）
                onAgree()

                // 念のため、短いクールダウン
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isSubmitting = false
                }
            } label: {
                HStack(spacing: 10) {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text(isSubmitting ? "処理中…" : "同意して続行")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Theme.sub.opacity(canProceed ? 1.0 : 0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canProceed)

            Text("※それぞれの本文を確認後、同意をONにしてください。")
                .font(.caption)
                .foregroundColor(Theme.semanticColor.text.opacity(0.55))
        }
    }

    private func toggleRow(title: String, isOn: Binding<Bool>, isEnabled: Bool) -> some View {
        HStack(spacing: 10) {
            Toggle(isOn: isOn) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.semanticColor.text.opacity(0.82))
            }
            .tint(Theme.sub)
            .disabled(!isEnabled)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private func badge(isReviewed: Bool) -> some View {
        let fg = Color.white
        let bg = (isReviewed ? Theme.semanticColor.success : Theme.semanticColor.warning).opacity(0.95)

        return Text(isReviewed ? "確認済" : "未確認")
            .font(.caption2.weight(.semibold))
            .foregroundColor(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(bg, in: Capsule())
    }
}

// MARK: - Sheet: 規約本文をScrollViewで読む
private struct LegalDocumentSheet: View {

    let title: String
    let bodyText: String
    let onReviewed: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reachedBottom: Bool = false

    var body: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            VStack(spacing: 12) {

                HStack {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Theme.semanticColor.text.opacity(0.9))
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.semanticColor.text.opacity(0.75))
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.70), in: Circle())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                ScrollView {
                    Text(bodyText)
                        .font(.footnote)
                        .foregroundColor(Theme.semanticColor.text.opacity(0.78))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)

                    GeometryReader { _ in
                        Color.clear
                            .frame(height: 1)
                            .onAppear { reachedBottom = true }
                    }
                    .frame(height: 1)
                }
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Theme.semanticColor.card)
                        .shadow(color: Theme.dark.opacity(0.10), radius: 10, y: 6)
                )
                .padding(.horizontal, 18)

                GlassButton(
                    title: reachedBottom ? "確認しました（閉じる）" : "最後までスクロールしてください",
                    systemImage: reachedBottom ? "checkmark.circle.fill" : "arrow.down.circle",
                    background: reachedBottom ? Theme.semanticColor.success : Theme.semanticColor.warning.opacity(0.35)
                ) {
                    guard reachedBottom else { return }
                    onReviewed()
                    dismiss()
                }
                .disabled(!reachedBottom)
                .opacity(reachedBottom ? 1.0 : 0.6)
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
    }
}
