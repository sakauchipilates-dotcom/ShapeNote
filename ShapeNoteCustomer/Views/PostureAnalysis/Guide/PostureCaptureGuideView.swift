import SwiftUI
import ShapeCore

struct PostureCaptureGuideView: View {

    let onClose: () -> Void
    let onGoCamera: () -> Void

    var body: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            VStack(spacing: 16) {

                // Close
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(Theme.dark.opacity(0.55))
                            .padding(10)
                    }
                    Spacer()
                }

                // Title
                VStack(spacing: 8) {
                    Text("撮影前のポイント")
                        .font(.title3.bold())
                        .foregroundColor(Theme.dark)

                    // ここはユーザー指摘で重複しやすいので、短くしても良いが一旦現状維持
                    Text("このあとスマホを置いて離れます。先に内容を確認してから撮影に進みましょう。")
                        .font(.footnote)
                        .foregroundColor(Theme.dark.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 4)

                // Cards
                VStack(spacing: 12) {

                    // ✅ 確認カード（注意色）
                    guideRow(
                        kindTitle: "確認",
                        title: "撮影前に読んでください",
                        body: "スマホを置いて離れる前に、以下のポイントを確認します。撮影を始める前に一度目を通してください。",
                        icon: "exclamationmark.triangle.fill",
                        iconTint: Color.red.opacity(0.85),
                        accent: .warning
                    )

                    guideRow(
                        kindTitle: "STEP 1",
                        title: "足幅を整える",
                        body: "足幅は腰幅で、安定して立ちます。",
                        icon: "arrow.left.and.right",
                        iconTint: Theme.sub,
                        accent: .normal
                    )

                    guideRow(
                        kindTitle: "STEP 2",
                        title: "姿勢を整える",
                        body: "腕は自然に体の横へ下ろし、背筋を伸ばして正面を向きます。",
                        icon: "figure.stand",
                        iconTint: Theme.sub,
                        accent: .normal
                    )

                    guideRow(
                        kindTitle: "STEP 3",
                        title: "立ち位置の調整",
                        body: "全身が縦長のガイド枠内に収まる位置へ移動します。",
                        icon: "rectangle.portrait",
                        iconTint: Theme.sub,
                        accent: .normal
                    )

                    // ✅ ジェスチャー文言は削除して「撮影」だけに戻す
                    guideRow(
                        kindTitle: "STEP 4",
                        title: "撮影",
                        body: "姿勢が整ったら撮影を開始します。",
                        icon: "camera",
                        iconTint: Theme.sub,
                        accent: .normal
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                Spacer()

                GlassButton(
                    title: "ガイドを確認して撮影へ",
                    systemImage: "camera.viewfinder",
                    background: Theme.sub
                ) {
                    onGoCamera()
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }
}

// MARK: - Row UI
private extension PostureCaptureGuideView {

    enum Accent {
        case normal
        case warning
    }

    func guideRow(
        kindTitle: String,
        title: String,
        body: String,
        icon: String,
        iconTint: Color,
        accent: Accent
    ) -> some View {

        let bg = Color.white.opacity(0.78)
        let stroke: Color = (accent == .warning)
            ? Color.red.opacity(0.25)
            : Color.white.opacity(0.55)

        return HStack(spacing: 14) {

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accent == .warning ? Color.red.opacity(0.12) : Theme.sub.opacity(0.12))

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconTint)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(kindTitle)
                        .font(.caption.bold())
                        .foregroundColor(accent == .warning ? Color.red.opacity(0.85) : Theme.dark.opacity(0.55))

                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.dark)
                }

                Text(body)
                    .font(.footnote)
                    .foregroundColor(Theme.dark.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, accent == .warning ? 16 : 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(bg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        )
        .shadow(color: Theme.shadow, radius: 10, x: 0, y: 6)
    }
}
