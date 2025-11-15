import SwiftUI
import ShapeCore

struct PostureAnalysisEntryView: View {

    // ① ガイド表示用
    @State private var showGuide: Bool = false

    // ② カメラフロー表示用
    @State private var showCameraFlow: Bool = false

    var body: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            VStack(spacing: 24) {

                Spacer().frame(height: 40)

                // アイコン
                Image(systemName: "figure.stand")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .foregroundColor(Theme.sub)

                // タイトル
                Text("AI姿勢分析を始めましょう")
                    .font(.title3.bold())
                    .foregroundColor(Theme.dark)

                // 説明文
                Text("カメラを使用して姿勢をチェックします。撮影画像は端末内で処理され、保存されません。")
                    .font(.footnote)
                    .foregroundColor(Theme.dark.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                // 「撮影を開始」→ まずガイド画面を出す
                GlassButton(
                    title: "撮影を開始",
                    systemImage: "camera.viewfinder",
                    background: Theme.sub
                ) {
                    showGuide = true
                }
                .frame(maxWidth: 320)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        // STEP ガイド画面
        .fullScreenCover(isPresented: $showGuide) {
            PostureCaptureGuideView(
                onClose: { showGuide = false },
                onGoCamera: {
                    showGuide = false
                    showCameraFlow = true
                }
            )
        }
        // 既存のカメラフロー（ここは今まで通り）
        .fullScreenCover(isPresented: $showCameraFlow) {
            PostureCameraFlowView()
        }
    }
}
