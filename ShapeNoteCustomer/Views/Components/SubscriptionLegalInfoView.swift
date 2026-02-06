import SwiftUI

/// サブスクリプションの法的情報とリンクをまとめて表示する共通コンポーネント
struct SubscriptionLegalInfoView: View {

    // App Store Connect に設定している URL と合わせる
    private let privacyURL = URL(string: "https://sites.google.com/view/shapenote-help")!
    private let termsURL   = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ご利用にあたって")
                .font(.footnote)
                .fontWeight(.semibold)

            Text("ShapeNote プレミアム（月額）は月額440円の自動更新サブスクリプションです。いつでも「設定」アプリからサブスクリプションをキャンセルできます。")
                .font(.footnote)

            HStack {
                Link("プライバシーポリシー", destination: privacyURL)
                Spacer(minLength: 16)
                Link("利用規約（EULA）", destination: termsURL)
            }
            .font(.footnote)
        }
        .foregroundColor(.secondary)
    }
}
