import SwiftUI
import AVFoundation
import ShapeCore

struct PostureAnalysisCameraView: View {

    @EnvironmentObject var cameraVM: PostureCameraVM

    let onClose: () -> Void
    let onCaptured: () -> Void

    var body: some View {
        ZStack {

            CameraPreview(session: cameraVM.captureSession)
                .ignoresSafeArea()

            CameraGuideOverlay()

            if cameraVM.isCountingDown {
                CircleCountdown(
                    count: cameraVM.countdown,
                    total: cameraVM.countdownTotal
                )
            }

            VStack {
                HStack {
                    Button {
                        cameraVM.stopSession()
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.9))
                            .padding()
                    }
                    Spacer()
                }

                Spacer()

                if !cameraVM.isCountingDown {
                    VStack(spacing: 20) {

                        Text(cameraVM.permissionDenied
                             ? "カメラアクセスが許可されていません。"
                             : "位置を調整し、撮影ボタンを押してください。")
                            .font(Theme.subtitle)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.bottom, 10)

                        GlassButton(
                            title: "撮影を開始",
                            systemImage: "camera.circle.fill",
                            background: Theme.sub
                        ) {
                            startCountdown()
                        }
                    }
                    .padding(.bottom, 60)
                }
            }
        }
        .onAppear {
            print("DEBUG: 📷 CameraView appeared")
            cameraVM.requestPermissionIfNeeded()
            cameraVM.configureSessionIfNeeded()
        }
        .onDisappear {
            if cameraVM.freezeDisappear {
                print("DEBUG: 📷 CameraView disappeared (freeze中) → stopSession スキップ")
                return
            }
            print("DEBUG: 📷 CameraView disappeared → stop session")
            cameraVM.stopSession()
        }
        .alert("カメラアクセスが必要です", isPresented: $cameraVM.permissionDenied) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("姿勢分析を行うにはカメラの使用許可が必要です。")
        }
        .navigationBarBackButtonHidden(true)
    }
}

extension PostureAnalysisCameraView {

    private func startCountdown() {
        cameraVM.startCountdown {
            takePhoto()
        }
    }

    private func takePhoto() {
        print("DEBUG: ▶︎ CameraView.takePhoto() 呼び出し")

        cameraVM.freezeDisappear = true
        print("DEBUG: freezeDisappear = true")

        cameraVM.capturePhoto {
            print("DEBUG: ▶︎ CameraView.onFinish 撮影終了")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.cameraVM.freezeDisappear = false
                print("DEBUG: freezeDisappear = false（confirm 遷移直前）")

                if self.cameraVM.capturedImage != nil {
                    print("DEBUG: 🟢 撮影画像あり → confirmへ遷移")
                    self.onCaptured()
                } else {
                    print("DEBUG: 🔴 撮影画像 nil → 遷移しない")
                }
            }
        }
    }
}
