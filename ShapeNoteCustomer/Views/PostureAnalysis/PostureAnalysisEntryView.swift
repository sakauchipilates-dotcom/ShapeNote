import SwiftUI
import AVFoundation
import ShapeCore

struct PostureAnalysisEntryView: View {

    @State private var showCameraFlow = false
    @State private var showPermissionAlert = false

    var body: some View {
        ZStack {
            Theme.gradientMain
                .ignoresSafeArea()

            VStack(spacing: 28) {

                Spacer().frame(height: 40)

                Image(systemName: "figure.stand")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .foregroundColor(Theme.sub)

                Text("AI姿勢分析を始めましょう")
                    .font(Theme.title)
                    .foregroundColor(Theme.dark)
                    .padding(.bottom, 4)

                Text("カメラを使用して姿勢をチェックします。\n撮影画像は端末内で処理され、保存されません。")
                    .font(Theme.body)
                    .foregroundColor(Theme.dark.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Spacer()

                GlassButton(
                    title: "撮影を開始",
                    systemImage: "camera.viewfinder",
                    background: Theme.sub
                ) {
                    startFlow()
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .alert("カメラアクセスが許可されていません", isPresented: $showPermissionAlert) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("姿勢分析を行うにはカメラの使用許可が必要です。")
        }
        .fullScreenCover(isPresented: $showCameraFlow) {
            PostureCameraFlowView()
        }
    }

    // MARK: - カメラ権限チェック → Flow 開始
    private func startFlow() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    showCameraFlow = true
                } else {
                    showPermissionAlert = true
                }
            }
        }
    }
}
