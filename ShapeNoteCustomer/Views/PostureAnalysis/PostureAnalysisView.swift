import SwiftUI
import AVFoundation

struct PostureAnalysisView: View {

    /// CustomerRootView から渡される push 操作
    let push: (PostureRoute) -> Void

    @State private var showPermissionAlert = false

    var body: some View {
        VStack(spacing: 30) {

            // アイコン
            Image(systemName: "viewfinder.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue.opacity(0.8))
                .padding(.top, 80)

            // タイトル
            Text("AI姿勢分析を始めましょう")
                .font(.title3.bold())
                .padding(.bottom, 8)

            // 説明文
            Text("""
                 カメラを使用して姿勢をチェックします。
                 撮影画像は端末内で処理され、保存されません。
                 """)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // ボタン
            Button(action: startGuide) {
                Label("姿勢チェックを開始", systemImage: "camera.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 20)

            Spacer()
        }
        .navigationTitle("姿勢分析")
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
    }

    // MARK: - カメラ権限チェック → ガイドへ push
    private func startGuide() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    /// 🔥 NavigationStack の path に追加
                    push(.guide)
                } else {
                    showPermissionAlert = true
                }
            }
        }
    }
}
