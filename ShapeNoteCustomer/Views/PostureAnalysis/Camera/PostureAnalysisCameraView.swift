import SwiftUI
import AVFoundation
import ShapeCore

struct PostureAnalysisCameraView: View {

    @EnvironmentObject var cameraVM: PostureCameraVM

    let onClose: () -> Void
    let onCaptured: () -> Void

    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        ZStack {

            // MARK: - カメラプレビュー（最背面）
            CameraPreview(session: cameraVM.captureSession)
                .ignoresSafeArea()

            // ガイド線
            CameraGuideOverlay()

            // MARK: - カウントダウン
            if cameraVM.isCountingDown {
                CircleCountdown(
                    count: cameraVM.countdown,
                    total: cameraVM.countdownTotal
                )
            }

            // MARK: - 上部 UI
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

                // MARK: - 撮影開始ボタン（カウントダウン中は非表示）
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

            // ===================================================
            // MARK: - UI オーバーレイ（state 紐付け）
            // ===================================================

            switch cameraVM.state {

            // -------------------------------------------------------
            // ① 準備中 overlay
            // -------------------------------------------------------
            case .preparing:
                Color.white.opacity(0.75)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("カメラを準備しています…")
                                .font(.headline)
                                .foregroundColor(Theme.dark)
                        }
                    )

            // -------------------------------------------------------
            // ② 権限リクエスト中（タッチ無効化のみ）
            // -------------------------------------------------------
            case .requestingPermission:
                Color.clear
                    .ignoresSafeArea()
                    .allowsHitTesting(true) // 全タッチ無効化

            // -------------------------------------------------------
            // ④ 撮影中 overlay（軽いフェード）
            // -------------------------------------------------------
            case .capturing:
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )

            // -------------------------------------------------------
            // ⑤ エラー（alertを外で表示）
            // -------------------------------------------------------
            case .error(let msg):
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onAppear {
                        errorMessage = msg
                        showErrorAlert = true
                    }

            default:
                EmptyView()
            }
        }
        .onAppear {
            print("DEBUG: 📷 CameraView appeared")
            cameraVM.requestPermissionIfNeeded()
            cameraVM.configureSessionIfNeeded()
        }
        .onDisappear {
            if cameraVM.freezeDisappear {
                print("DEBUG: 📷 disappear (freeze中) → stopSession SKIP")
                return
            }
            cameraVM.stopSession()
        }
        .alert("エラーが発生しました", isPresented: $showErrorAlert) {

            Button("再試行") {
                cameraVM.reset()
                cameraVM.requestPermissionIfNeeded()
                cameraVM.configureSessionIfNeeded()
            }

            Button("閉じる", role: .cancel) {
                onClose()
            }

        } message: {
            Text(errorMessage)
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

        cameraVM.capturePhoto {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.cameraVM.freezeDisappear = false

                if self.cameraVM.capturedImage != nil {
                    self.onCaptured()
                }
            }
        }
    }
}
