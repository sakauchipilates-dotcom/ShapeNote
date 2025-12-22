import SwiftUI
import AVFoundation
import ShapeCore

struct PostureAnalysisCameraView: View {

    @EnvironmentObject var cameraVM: PostureCameraVM

    let onClose: () -> Void
    let onCaptured: () -> Void   // 4枚揃ったら呼ぶ

    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        ZStack {

            CameraPreview(session: cameraVM.captureSession)
                .ignoresSafeArea()

            CameraGuideOverlay()

            topOverlay

            if cameraVM.isCountingDown {
                CircleCountdown(
                    count: cameraVM.countdown,
                    total: cameraVM.countdownTotal
                )
            }

            bottomUI

            switch cameraVM.state {
            case .preparing:
                Color.white.opacity(0.75)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("カメラを準備しています…")
                                .font(.headline)
                                .foregroundColor(Theme.dark)
                        }
                    )

            case .requestingPermission:
                Color.clear.ignoresSafeArea().allowsHitTesting(true)

            case .capturing:
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .overlay(ProgressView())

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
            cameraVM.requestPermissionIfNeeded()

            // 権限未確定中にconfigureすると詰まることがあるので、拒否でない場合のみ
            if !cameraVM.permissionDenied {
                cameraVM.configureSessionIfNeeded()
            }
        }
        .onChange(of: cameraVM.permissionDenied) { denied in
            if !denied {
                cameraVM.configureSessionIfNeeded()
            }
        }
        .onChange(of: cameraVM.shots.count) { newCount in
            if newCount >= 4 {
                // 4枚揃ったら：遷移前にセッション停止（メモリピーク抑制）
                cameraVM.freezeDisappear = true
                cameraVM.stopSession()

                DispatchQueue.main.async {
                    onCaptured()
                }
            }
        }
        .onDisappear {
            if cameraVM.freezeDisappear { return }
            cameraVM.stopSession()
        }
        .alert("エラーが発生しました", isPresented: $showErrorAlert) {

            Button("再試行") {
                cameraVM.reset()
                cameraVM.requestPermissionIfNeeded()
                if !cameraVM.permissionDenied {
                    cameraVM.configureSessionIfNeeded()
                }
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

// MARK: - 上部
private extension PostureAnalysisCameraView {

    var topOverlay: some View {
        VStack {
            HStack {
                Button {
                    cameraVM.freezeDisappear = false
                    cameraVM.stopSession()
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(12)
                }

                Spacer()

                if cameraVM.isCountingDown {
                    Button {
                        cameraVM.cancelSequence()
                    } label: {
                        Text("キャンセル")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.95))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.35), in: Capsule())
                    }
                    .padding(12)
                }
            }

            Spacer()
        }
        .padding(.top, 6)
    }
}

// MARK: - 下部UI
private extension PostureAnalysisCameraView {

    var bottomUI: some View {
        VStack {
            Spacer()

            if !cameraVM.isCountingDown {

                VStack(spacing: 14) {

                    Text(instructionText)
                        .font(Theme.subtitle)
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)

                    GlassButton(
                        title: "15秒後に撮影",
                        systemImage: "timer",
                        background: Theme.sub
                    ) {
                        cameraVM.startSequence()
                    }
                }
                .padding(.bottom, 60)
            } else {
                Text("\(cameraVM.currentDirection.title)を撮影します")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.bottom, 90)
            }
        }
    }

    var instructionText: String {
        if cameraVM.permissionDenied {
            return "カメラアクセスが許可されていません。"
        }

        if cameraVM.shots.isEmpty {
            return "正面を撮影します。ボタンを押すと15秒後に撮影します。押したらスマホから離れて位置を調整してください。"
        } else {
            return "\(cameraVM.currentDirection.instruction) 自動で撮影します。"
        }
    }
}
