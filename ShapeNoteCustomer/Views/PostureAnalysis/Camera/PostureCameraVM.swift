import SwiftUI
import AVFoundation
import Combine

final class PostureCameraVM: NSObject, ObservableObject {

    // MARK: - 公開状態（View が読む）
    @Published var capturedImage: UIImage? = nil          // 撮影画像
    @Published var isSessionRunning: Bool = false         // セッション稼働中フラグ
    @Published var permissionDenied: Bool = false         // 権限NG

    // カウントダウン（秒）
    @Published var countdown: Int = 15
    let countdownTotal: Int = 15
    @Published var isCountingDown: Bool = false

    /// 撮影直後に onDisappear 側の stopSession を抑制するフラグ
    @Published var freezeDisappear: Bool = false

    // MARK: - AVFoundation 基本構造
    fileprivate let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()

    var captureSession: AVCaptureSession { session }

    private var countdownTimer: Timer?

    /// 撮影中の PhotoCaptureHandler を強参照で保持するためのプロパティ
    private var photoHandler: PhotoCaptureHandler?

    /// capture 用のシリアルキュー
    private let captureQueue = DispatchQueue(label: "PostureCameraCaptureQueue")

    override init() {
        super.init()
    }

    // MARK: - リセット（Flow 開始時に呼ぶ想定）
    func reset() {
        print("DEBUG: 🔁 CameraVM.reset()")
        capturedImage = nil
        countdown = countdownTotal
        isCountingDown = false
        freezeDisappear = false
    }

    // MARK: - 権限確認
    func requestPermissionIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.permissionDenied = !granted
                    print("DEBUG: 🎛 Camera permission granted=\(granted)")
                }
            }

        default:
            permissionDenied = true
        }
    }

    // MARK: - セッション構成（必要ならセットアップ）
    func configureSessionIfNeeded() {
        guard session.inputs.isEmpty else {
            // 既に構成済みならそのまま開始だけ
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
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        // 端末によってはこれがないと delegate が呼ばれないケースがある
        photoOutput.isHighResolutionCaptureEnabled = true

        session.commitConfiguration()
        startSession()
    }

    // MARK: - セッション開始
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
                print("DEBUG: ▶︎ Session running = \(self.isSessionRunning)")
            }
        }
    }

    // MARK: - セッション停止
    func stopSession() {
        // カウントダウンは必ず止める
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountingDown = false

        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                    print("DEBUG: ▶︎ Session stopped")
                }
            } else {
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }

    // MARK: - カウントダウン（15秒）
    func startCountdown(onFinish: @escaping () -> Void) {
        print("DEBUG: ▶︎ startCountdown()")
        countdownTimer?.invalidate()

        countdown = countdownTotal
        isCountingDown = true

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
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

    // MARK: - 撮影（セッション準備のリトライ込み）
    func capturePhoto(onFinish: @escaping () -> Void) {
        print("DEBUG: 📸 VM.capturePhoto()")

        // 以前のハンドラをクリア
        photoHandler = nil

        let settings = AVCapturePhotoSettings()

        // セッション準備 → 撮影 をリトライ付きで実行
        internalCapturePhoto(settings: settings, retryCount: 0, onFinish: onFinish)
    }

    /// 実際の撮影処理（セッション準備を見て最大3回までリトライ）
    private func internalCapturePhoto(
        settings: AVCapturePhotoSettings,
        retryCount: Int,
        onFinish: @escaping () -> Void
    ) {
        let maxRetries = 3

        // 現在のセッション状態をチェック
        let isReady = session.isRunning &&
                      !session.inputs.isEmpty &&
                      !session.outputs.isEmpty

        guard isReady else {
            print("""
            DEBUG: ⚠️ capturePhoto スキップ: session not ready \
            (isRunning=\(session.isRunning), inputs=\(session.inputs.count), outputs=\(session.outputs.count), retry=\(retryCount))
            """)

            if retryCount < maxRetries {
                // セッションを起動して少し待って再トライ
                startSession()
                let delay: TimeInterval = 0.25
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.internalCapturePhoto(
                        settings: settings,
                        retryCount: retryCount + 1,
                        onFinish: onFinish
                    )
                }
            } else {
                print("DEBUG: ❌ capturePhoto 断念: session が準備完了にならず")
                onFinish()
            }
            return
        }

        print("DEBUG: ▶︎ capturePhoto 実行 (retry=\(retryCount))")

        // ここから実際の撮影
        let handler = PhotoCaptureHandler { [weak self] image in
            guard let self else { return }

            DispatchQueue.main.async {
                if let img = image {
                    print("DEBUG: 🟩 撮影成功 → image.size=\(img.size)")
                    self.capturedImage = img
                } else {
                    print("DEBUG: ❌ 撮影画像 nil（PhotoCaptureHandler から）")
                }

                self.photoHandler = nil
                onFinish()
            }
        }

        self.photoHandler = handler
        photoOutput.capturePhoto(with: settings, delegate: handler)
    }
}
