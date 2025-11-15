import SwiftUI
import ShapeCore

/// 撮影前のSTEPガイド画面
struct PostureCaptureGuideView: View {

    let onClose: () -> Void
    let onGoCamera: () -> Void

    var body: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {

                    Spacer().frame(height: 32)

                    // タイトル
                    Text("撮影前のポイント")
                        .font(.title3.bold())
                        .foregroundColor(Theme.dark)

                    // サブ説明
                    Text("正確な姿勢分析のため、以下のSTEPに沿って立ち位置を整えてから撮影してください。")
                        .font(.footnote)
                        .foregroundColor(Theme.dark.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer().frame(height: 8)

                    // STEP 1〜4
                    VStack(spacing: 18) {
                        GuideStepCard(
                            title: "STEP 1",
                            description: "足幅は腰幅で、まっすぐ立ちましょう。",
                            systemImage: "figure.stand"
                        )

                        GuideStepCard(
                            title: "STEP 2",
                            description: "腕は自然に身体の横へ下ろします。",
                            systemImage: "arrow.up.left.and.arrow.down.right"
                        )

                        GuideStepCard(
                            title: "STEP 3",
                            description: "全身がガイド枠内に収まるように調整してください。",
                            systemImage: "rectangle.dashed"
                        )

                        GuideStepCard(
                            title: "STEP 4",
                            description: "姿勢を整えて撮影ボタンを押してください。",
                            systemImage: "camera"
                        )
                    }
                    .padding(.top, 8)

                    Spacer().frame(height: 24)

                    // 撮影へ進むボタン
                    GlassButton(
                        title: "ガイドを確認して撮影へ",
                        systemImage: "camera.circle.fill",
                        background: Theme.sub
                    ) {
                        onGoCamera()
                    }
                    .frame(maxWidth: 320)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }

            // 左上の閉じるボタン
            VStack {
                HStack {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(Theme.dark.opacity(0.6))
                            .padding(.leading, 16)
                            .padding(.top, 12)
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .interactiveDismissDisabled(true)
    }
}
