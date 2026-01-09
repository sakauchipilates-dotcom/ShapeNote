import SwiftUI
import ShapeCore

/// 退会（アカウント削除）申請後に表示するガード画面（App Review 向け）
///
/// 目的:
/// - 退会申請が「正常に受理された」ことを明示する
/// - 申請後はログイン不可である理由を説明する
/// - 本挙動が不具合ではなく、仕様であることを明確にする
struct DeletionRequestGuardView: View {

    /// CustomerAppState.deletionGuardMessage をそのまま表示（任意）
    let message: String?

    var body: some View {
        ZStack {
            Theme.gradientMain
                .ignoresSafeArea()

            VStack {
                Spacer(minLength: 0)

                card

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarHidden(true)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {

            // タイトル
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.xmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.semanticColor.warning.opacity(0.9))

                Text("退会申請を受け付けました")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Theme.semanticColor.text.opacity(0.92))
            }

            // メイン説明文（1パラグラフ）
            Text(message ?? defaultMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.vertical, 4)

            // 補足説明（仕様明示）
            VStack(alignment: .leading, spacing: 8) {
                bullet("退会申請後は、セキュリティおよびデータ保護のためログインできません。")
                bullet("アカウント削除または匿名化処理は、運営側で順次対応いたします。")
                bullet("本画面は不具合ではなく、仕様に基づく案内画面です。")
            }
            .font(.footnote)
            .foregroundColor(.secondary)

        }
        .padding(18)
        .frame(maxWidth: 520)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.semanticColor.card)
                .shadow(color: Theme.dark.opacity(0.12), radius: 14, y: 8)
        )
    }

    private var defaultMessage: String {
        """
        退会（アカウント削除）申請の受付が完了しました。
        現在、申請内容を確認のうえ、運営側にて処理を進めています。
        """
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    DeletionRequestGuardView(
        message: "退会申請を受け付けています。処理完了までログインできません。"
    )
}
