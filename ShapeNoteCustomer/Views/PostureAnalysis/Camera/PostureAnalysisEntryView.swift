import SwiftUI
import ShapeCore

struct PostureAnalysisEntryView: View {

    /// 姿勢分析カメラフローの表示フラグ（ローカル State）
    @State private var showCameraFlow: Bool = false

    var body: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            VStack(spacing: 32) {

                Spacer().frame(height: 40)

                Image(systemName: "figure.stand")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundColor(Theme.sub)

                Text("AI姿勢分析を始めましょう")
                    .font(.title2.bold())
                    .foregroundColor(Theme.dark)

                Text("カメラを使用して姿勢をチェックします。撮影画像は端末内で処理され、保存されません。")
                    .font(.body)
                    .foregroundColor(Theme.dark.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                // 撮影開始ボタン
                GlassButton(
                    title: "撮影を開始",
                    systemImage: "camera.circle.fill",
                    background: Theme.sub
                ) {
                    showCameraFlow = true
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 40)
            }
        }
        // ここでカメラフローを fullScreenCover で表示
        .fullScreenCover(isPresented: $showCameraFlow) {
            PostureCameraFlowView()
        }
    }
}
