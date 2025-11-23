import SwiftUI
import AVFoundation
import Combine

// MARK: - CameraState
enum CameraState: Equatable {
    case idle
    case requestingPermission
    case permissionDenied
    case preparing
    case ready
    case countingDown
    case capturing
    case finished
    case error(String)
}

final class PostureCameraVM: NSObject, ObservableObject {

    // MARK: - 公開状態
    @Published var capturedImage: UIImage? = nil
    @Published var isSessionRunning: Bool = false
    @Published var permissionDenied: Bool = false

    @Published var countdown: Int = 15
    let countdownTotal: Int = 15
    @Published var isCountingDown: Bool = false

    /// onDisappear → stopSession を抑制
    @Published var freezeDisappear: Bool = false

    /// 状態管理
    @Published var state: CameraState = .idle

    // MARK: - AVFoundation 基盤
    fileprivate let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()

    var captureSession: AVCaptureSession { session }

    private var countdownTimer: Timer?
    private var photoHandler: PhotoCaptureHandler?

    /// capture 用のシリアルキュー
    private let captureQueue = DispatchQueue(label: "PostureCameraCaptureQueue")

    override init() {
        super.init()
    }

    // MARK: - リセット（Flow 開始時）
    func reset() {
        print("DEBUG: 🔁 CameraVM.reset()")

        capturedImage = nil
        countdown = countdownTotal
        isCountingDown = false
        freezeDisappear = false

        state = .idle
    }

    // MARK: - ① 権限確認（state 紐付け）
    func requestPermissionIfNeeded() {

        state = .requestingPermission

        switch AVCaptureDevice.authorizationStatus(for: .video) {

        case .authorized:
            // すでに許可済み
            return

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.permissionDenied = false
                        print("DEBUG: 🎛 Camera permission granted")
                    } else {
                        self.permissionDenied = true
                        self.state = .permissionDenied
                        print("DEBUG: ❌ Camera permission denied")
                    }
                }
            }

        default:
            permissionDenied = true
            state = .permissionDenied
        }
    }

    // MARK: - ② セッション準備（state 紐付け）
    func configureSessionIfNeeded() {

        state = .preparing

        guard session.inputs.isEmpty else {
            // 構成済 → すぐスタート
            startSession()
            return
        }

        session.beginConfiguration()

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video,
                                                 position: .front),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            print("DEBUG: ❌ Camera device / input の取得に失敗")
            state = .error("カメラデバイスの取得に失敗しました")
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        photoOutput.isHighResolutionCaptureEnabled = true

        session.commitConfiguration()
        startSession()
    }

    // MARK: - セッション開始（準備完了 → ready）
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async {

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
                print("DEBUG: ▶︎ Session running = \(self.isSessionRunning)")

                if self.isSessionRunning {
                    self.state = .ready
                }
            }
        }
    }

    // MARK: - セッション停止
    func stopSession() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountingDown = false

        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isSessionRunning = false
                print("DEBUG: ▶︎ Session stopped")
            }
        }
    }

    // MARK: - ③ カウントダウン開始（state 紐付け）
    func startCountdown(onFinish: @escaping () -> Void) {
        print("DEBUG: ▶︎ startCountdown()")

        state = .countingDown

        countdownTimer?.invalidate()
        countdown = countdownTotal
        isCountingDown = true

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] timer in
            guard let self else { return }

            self.countdown -= 1
            print("DEBUG: countdown = \(self.countdown)")

            if self.countdown <= 0 {
                timer.invalidate()
                self.countdownTimer = nil
                self.isCountingDown = false
                onFinish()
            }
        }
    }

    // MARK: - ④ 撮影（state 紐付け）
    func capturePhoto(onFinish: @escaping () -> Void) {
        print("DEBUG: 📸 VM.capturePhoto()")

        state = .capturing

        photoHandler = nil
        let settings = AVCapturePhotoSettings()

        internalCapturePhoto(
            settings: settings,
            retryCount: 0,
            onFinish: onFinish
        )
    }

    // MARK: - 内部撮影処理
    private func internalCapturePhoto(
        settings: AVCapturePhotoSettings,
        retryCount: Int,
        onFinish: @escaping () -> Void
    ) {
        let maxRetries = 3

        let isReady = session.isRunning &&
                      !session.inputs.isEmpty &&
                      !session.outputs.isEmpty

        guard isReady else {

            print("""
            DEBUG: ⚠️ capturePhoto スキップ: session not ready \
            (isRunning=\(session.isRunning), inputs=\(session.inputs.count), outputs=\(session.outputs.count), retry=\(retryCount))
            """)

            if retryCount < maxRetries {
                startSession()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    [weak self] in
                    self?.internalCapturePhoto(
                        settings: settings,
                        retryCount: retryCount + 1,
                        onFinish: onFinish
                    )
                }
            } else {
                print("DEBUG: ❌ capturePhoto 断念")
                state = .error("撮影に失敗しました")
                onFinish()
            }
            return
        }

        print("DEBUG: ▶︎ capturePhoto 実行 (retry=\(retryCount))")

        let handler = PhotoCaptureHandler { [weak self] image in
            guard let self else { return }

            DispatchQueue.main.async {
                if let img = image {
                    print("DEBUG: 🟩 撮影成功 → image.size=\(img.size)")
                    print("DEBUG: orientation raw = \(img.imageOrientation.rawValue)")
                    print("DEBUG: scale = \(img.scale)")

                    self.capturedImage = img
                    self.state = .finished      // 撮影完了
                } else {
                    print("DEBUG: ❌ 撮影画像 nil")
                    self.state = .error("撮影画像の取得に失敗しました")
                }

                self.photoHandler = nil
                onFinish()
            }
        }

        self.photoHandler = handler
        photoOutput.capturePhoto(with: settings, delegate: handler)
    }
}
