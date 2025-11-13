import SwiftUI
import AVFoundation

struct PostureAnalysisCameraView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var session = AVCaptureSession()
    @State private var photoOutput = AVCapturePhotoOutput()
    @State private var isSessionRunning = false
    @State private var permissionDenied = false

    @State private var countdown = 15
    @State private var isCountingDown = false
    @State private var countdownStarted = false

    @State private var navigateToFlow = false
    @State private var capturedImage: UIImage?

    @State private var photoDelegate: PhotoCaptureDelegate?

    var body: some View {
        ZStack {

            /// カメラプレビュー
            CameraPreview(session: session)
                .ignoresSafeArea()

            /// カウントダウン表示
            if isCountingDown {
                Text("\(countdown)")
                    .font(.system(size: 100, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
            }

            /// UI
            VStack {

                /// 閉じる
                HStack {
                    Button {
                        stopSession()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                }

                Spacer()

                if !isCountingDown {
                    VStack(spacing: 20) {
                        Text(permissionDenied
                             ? "カメラアクセスが許可されていません"
                             : "位置を調整し、「撮影へ進む」ボタンを押してください。")
                            .font(.headline)
                            .foregroundColor(.white)

                        Button(action: startCountdown) {
                            Label("撮影へ進む", systemImage: "camera.circle.fill")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .padding(.horizontal, 40)
                        }
                    }
                    .padding(.bottom, 60)
                }
            }
        }
        .onAppear { checkCameraPermissionAndConfigure() }
        .onDisappear { stopSession() }
        .alert("カメラアクセスが許可されていません", isPresented: $permissionDenied) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("姿勢分析を行うにはカメラの使用許可が必要です。")
        }
        .navigationDestination(isPresented: $navigateToFlow) {
            if let img = capturedImage {
                PostureAnalysisFlowView(
                    capturedImage: img,
                    onRetake: {
                        /// 戻って再撮影
                        navigateToFlow = false
                        capturedImage = nil
                        resetCountdown()
                        startSession()
                    },
                    onClose: {
                        /// 完全に閉じる → ガイドへ戻る
                        navigateToFlow = false
                        capturedImage = nil
                        stopSession()
                        dismiss()
                    }
                )
            } else {
                LoadingFallbackView()
            }
        }
    }
}

// MARK: - カメラ制御 & 撮影処理
extension PostureAnalysisCameraView {

    private func startCountdown() {
        guard !permissionDenied else { return }

        countdown = 15
        isCountingDown = true
        countdownStarted = true

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            countdown -= 1
            if countdown == 0 {
                timer.invalidate()
                isCountingDown = false
                takePhoto()
            }
        }
    }

    private func resetCountdown() {
        countdown = 15
        isCountingDown = false
        countdownStarted = false
    }

    private func takePhoto() {
        let settings = AVCapturePhotoSettings()

        let delegate = PhotoCaptureDelegate { image in
            guard let image = image else { return }

            DispatchQueue.main.async {
                self.capturedImage = image
            }

            /// カメラ停止はバックグラウンドで安全に実施
            DispatchQueue.global(qos: .userInitiated).async {

                self.session.stopRunning()
                usleep(200_000) // 0.2 秒：iOS16〜17で最も安定

                /// 停止が完了してから遷移
                DispatchQueue.main.async {
                    self.navigateToFlow = true
                    self.photoDelegate = nil
                }
            }
        }

        self.photoDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private func checkCameraPermissionAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    granted ? configureCamera() : (permissionDenied = true)
                }
            }
        default:
            permissionDenied = true
        }
    }

    private func configureCamera() {
        session.beginConfiguration()

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {

            print("❌ カメラデバイスの取得に失敗")
            session.commitConfiguration()
            return
        }

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        session.commitConfiguration()
        startSession()
    }

    private func startSession() {
        guard !isSessionRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            DispatchQueue.main.async { isSessionRunning = true }
        }
    }

    private func stopSession() {
        guard isSessionRunning else { return }
        DispatchQueue.global(qos: .background).async {
            session.stopRunning()
            DispatchQueue.main.async { isSessionRunning = false }
        }
    }
}

/// 撮影画像が無い場合のフォールバック
struct LoadingFallbackView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("画像を準備しています…")
                    .foregroundColor(.white)
                    .font(.headline)
            }
        }
    }
}
