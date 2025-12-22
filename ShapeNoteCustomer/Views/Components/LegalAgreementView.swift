import SwiftUI

struct LegalAgreementView: View {

    let termsURL: URL
    let privacyURL: URL
    let onAgree: () -> Void
    let onLogout: () -> Void

    @State private var agreedTerms = false
    @State private var agreedPrivacy = false

    var body: some View {
        ZStack {
            // 背景：既存UIを邪魔しない薄いグラデ
            LinearGradient(
                colors: [
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {

                Text("利用規約・プライバシーポリシー")
                    .font(.title3.bold())
                    .foregroundColor(.primary)

                Text("""
                本サービスでは体重・身長などの記録データを扱います。
                ご利用には以下への同意が必要です。
                """)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 12) {

                    Toggle(isOn: $agreedTerms) {
                        Link("利用規約を確認して同意する", destination: termsURL)
                            .font(.subheadline.weight(.semibold))
                    }

                    Toggle(isOn: $agreedPrivacy) {
                        Link("プライバシーポリシーを確認して同意する", destination: privacyURL)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.top, 6)

                Button {
                    onAgree()
                } label: {
                    Text("同意して始める")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!(agreedTerms && agreedPrivacy))

                Button(role: .destructive) {
                    onLogout()
                } label: {
                    Text("同意しない（ログアウト）")
                        .font(.footnote)
                }
                .padding(.top, 4)
            }
            .padding(18)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, 18)
        }
        .interactiveDismissDisabled(true) // ← 絶対に閉じさせない
    }
}
