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

    // Countdown
    @Published var countdown: Int = 0
    @Published var countdownTotal: Int = 0
    @Published var isCountingDown: Bool = false

    /// onDisappear → stopSession を抑制
    @Published var freezeDisappear: Bool = false

    /// 状態管理
    @Published var state: CameraState = .idle

    // MARK: - 4方向シーケンス
    @Published var isSequencing: Bool = false
    @Published var currentDirection: PostureShotDirection = .front
    @Published var shots: [CapturedShot] = []

    // MARK: - AVFoundation
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

    // MARK: - リセット
    func reset() {
        print("DEBUG: 🔁 CameraVM.reset()")
        capturedImage = nil
        cancelCountdown()

        isSequencing = false
        currentDirection = .front
        shots.removeAll()

        freezeDisappear = false
        state = .idle
    }

    // MARK: - 権限
    func requestPermissionIfNeeded() {
        state = .requestingPermission

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionDenied = false
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

    // MARK: - セッション準備
    func configureSessionIfNeeded() {
        state = .preparing

        guard session.inputs.isEmpty else {
            startSession()
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            print("DEBUG: ❌ Camera device/input 取得失敗")
            state = .error("カメラデバイスの取得に失敗しました")
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        photoOutput.isHighResolutionCaptureEnabled = true

        // ✅ 写真は左右反転させない（プレビューだけミラー）
        if let conn = photoOutput.connection(with: .video) {
            if conn.isVideoMirroringSupported { conn.isVideoMirrored = false }
            if conn.isVideoOrientationSupported { conn.videoOrientation = .portrait }
        }

        session.commitConfiguration()
        startSession()
    }

    // MARK: - 開始
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

    // MARK: - 停止
    func stopSession() {
        cancelCountdown()

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

    // MARK: - カウントダウン（秒数指定）
    func startCountdown(seconds: Int,
                       onTick: ((Int) -> Void)? = nil,
                       onFinish: @escaping () -> Void) {
        guard seconds > 0 else { return }

        print("DEBUG: ▶︎ startCountdown(seconds: \(seconds))")
        state = .countingDown

        cancelCountdown()
        countdownTotal = seconds
        countdown = seconds
        isCountingDown = true

        onTick?(countdown)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { return }

            self.countdown -= 1
            onTick?(self.countdown)

            if self.countdown <= 0 {
                timer.invalidate()
                self.countdownTimer = nil
                self.isCountingDown = false
                onFinish()
            }
        }
    }

    func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountingDown = false
        countdown = 0
        countdownTotal = 0

        if state == .countingDown {
            state = .ready
        }
    }

    // MARK: - 撮影
    func capturePhoto(onFinish: @escaping () -> Void) {
        print("DEBUG: 📸 VM.capturePhoto()")
        state = .capturing

        photoHandler = nil
        let settings = AVCapturePhotoSettings()

        // 念のため毎回
        if let conn = photoOutput.connection(with: .video) {
            if conn.isVideoMirroringSupported { conn.isVideoMirrored = false }
            if conn.isVideoOrientationSupported { conn.videoOrientation = .portrait }
        }

        internalCapturePhoto(settings: settings, retryCount: 0, onFinish: onFinish)
    }

    private func internalCapturePhoto(settings: AVCapturePhotoSettings,
                                      retryCount: Int,
                                      onFinish: @escaping () -> Void) {
        let maxRetries = 3
        let isReady = session.isRunning && !session.inputs.isEmpty && !session.outputs.isEmpty

        guard isReady else {
            print("DEBUG: ⚠️ capturePhoto skip (retry=\(retryCount))")

            if retryCount < maxRetries {
                startSession()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    self?.internalCapturePhoto(settings: settings,
                                               retryCount: retryCount + 1,
                                               onFinish: onFinish)
                }
            } else {
                print("DEBUG: ❌ capturePhoto 断念")
                state = .error("撮影に失敗しました")
                onFinish()
            }
            return
        }

        let handler = PhotoCaptureHandler { [weak self] image in
            guard let self else { return }
            DispatchQueue.main.async {
                if let img = image {
                    self.capturedImage = img
                    self.state = .finished
                } else {
                    self.state = .error("撮影画像の取得に失敗しました")
                }
                self.photoHandler = nil
                onFinish()
            }
        }

        self.photoHandler = handler
        photoOutput.capturePhoto(with: settings, delegate: handler)
    }

    // MARK: - 4方向シーケンス制御

    /// 「15秒後に撮影」ボタンで呼ぶ
    func startSequence() {
        guard !permissionDenied else { return }
        guard state == .ready || state == .idle || state == .finished else { return }
        guard !isCountingDown else { return }

        VoiceGuide.shared.prepareIfNeeded()

        isSequencing = true
        shots.removeAll()
        currentDirection = .front

        announceAndCountdownForCurrent()
    }

    func cancelSequence() {
        cancelCountdown()
        isSequencing = false
        currentDirection = .front
        shots.removeAll()
        // readyに戻す
        if state != .error("カメラアクセスが許可されていません。") {
            state = .ready
        }
    }

    private func announceAndCountdownForCurrent() {
        let seconds = (currentDirection == .front) ? 15 : 10

        // 音声：向き + 秒数
        VoiceGuide.shared.speak("\(currentDirection.instruction)\(seconds)秒後に撮影します。")

        startCountdown(seconds: seconds, onTick: { sec in
            // 最後の3秒だけ読み上げ
            if sec == 3 { VoiceGuide.shared.speak("3") }
            if sec == 2 { VoiceGuide.shared.speak("2") }
            if sec == 1 { VoiceGuide.shared.speak("1") }
        }, onFinish: { [weak self] in
            self?.takeSequencePhoto()
        })
    }

    private func takeSequencePhoto() {
        freezeDisappear = true

        capturePhoto { [weak self] in
            guard let self else { return }

            DispatchQueue.main.async {
                // 失敗なら止める
                guard let img = self.capturedImage else {
                    self.isSequencing = false
                    return
                }

                // 保存
                let shot = CapturedShot(direction: self.currentDirection, image: img)
                self.shots.append(shot)

                // 次へ
                if self.shots.count >= 4 {
                    // 完了
                    self.isSequencing = false
                    // ここではセッションは止めない（Flow側で遷移するなら止めてもOK）
                    return
                }

                // 次の向きへ進める
                self.currentDirection = PostureShotDirection(rawValue: self.shots.count) ?? .left

                // 次の案内→カウントダウン開始（自動）
                self.announceAndCountdownForCurrent()
            }
        }
    }
}
