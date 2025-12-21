import SwiftUI
import ShapeCore

struct PostureAnalysisEntryView: View {

    // ガイド表示
    @State private var showGuide: Bool = false
    // カメラフロー
    @State private var showCameraFlow: Bool = false

    var body: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            VStack(spacing: 28) {

                Spacer().frame(height: 48)

                // MARK: - アイコン
                Image(systemName: "figure.stand")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .foregroundColor(Theme.sub)

                // MARK: - タイトル
                Text("AI姿勢分析を始めましょう")
                    .font(.title3.bold())
                    .foregroundColor(Theme.dark)

                // MARK: - 注意事項カード
                privacyCard
                    .padding(.horizontal, 24)

                Spacer()

                // MARK: - 撮影開始ボタン（グラデーション）
                Button {
                    showGuide = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 20, weight: .semibold))
                        Text("撮影を開始")
                            .font(.headline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [
                                Theme.sub,
                                Theme.sub.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Theme.shadow, radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        // MARK: - 撮影前ガイド
        .fullScreenCover(isPresented: $showGuide) {
            PostureCaptureGuideView(
                onClose: { showGuide = false },
                onGoCamera: {
                    showGuide = false
                    showCameraFlow = true
                }
            )
        }
        // MARK: - カメラフロー
        .fullScreenCover(isPresented: $showCameraFlow) {
            PostureCameraFlowView()
        }
    }
}

// MARK: - 注意事項カード
private extension PostureAnalysisEntryView {

    var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            noteRow(
                icon: safeSFSymbol(preferred: "camera.front.fill", fallback: "camera.fill"),
                text: "フロント（内側）カメラを使用します"
            )

            noteRow(
                icon: "lock.fill",
                text: "撮影画像は端末内のみで処理されます"
            )

            noteRow(
                icon: "nosign",
                text: "画像の保存・送信は行われません"
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: Theme.shadow, radius: 10, x: 0, y: 6)
    }

    func noteRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.sub.opacity(0.85))
                .frame(width: 18)

            Text(text)
                .font(.footnote)
                .foregroundColor(Theme.dark.opacity(0.85))

            Spacer(minLength: 0)
        }
    }

    /// iOS / SF Symbols差分で存在しないシンボルを指定すると表示されないことがあるため、
    /// 利用可能ならpreferred、ダメならfallbackに切り替える。
    func safeSFSymbol(preferred: String, fallback: String) -> String {
        if UIImage(systemName: preferred) != nil { return preferred }
        return fallback
    }
}
