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

    /// AVCaptureSession操作専用（重要）
    private let sessionQueue = DispatchQueue(label: "PostureCameraSessionQueue")

    /// capture処理用
    private let captureQueue = DispatchQueue(label: "PostureCameraCaptureQueue")

    /// shotsに保存する最大サイズ（小さくするほど落ちにくい）
    private let shotMaxDimension: CGFloat = 1440

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
                        // 権限が今取れたケースで準備へ進める
                        self.configureSessionIfNeeded()
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
        guard !permissionDenied else {
            state = .permissionDenied
            return
        }

        state = .preparing

        sessionQueue.async {
            if !self.session.inputs.isEmpty {
                self.startSession()
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                let input = try? AVCaptureDeviceInput(device: device)
            else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    print("DEBUG: ❌ Camera device/input 取得失敗")
                    self.state = .error("カメラデバイスの取得に失敗しました")
                }
                return
            }

            if self.session.canAddInput(input) { self.session.addInput(input) }
            if self.session.canAddOutput(self.photoOutput) { self.session.addOutput(self.photoOutput) }

            // メモリ/負荷対策：必要がなければ高解像度はOFF
            self.photoOutput.isHighResolutionCaptureEnabled = false

            if let conn = self.photoOutput.connection(with: .video) {
                if conn.isVideoMirroringSupported { conn.isVideoMirrored = false } // 写真はミラーしない
                if conn.isVideoOrientationSupported { conn.videoOrientation = .portrait }
            }

            self.session.commitConfiguration()
            self.startSession()
        }
    }

    // MARK: - 開始
    func startSession() {
        sessionQueue.async {
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

        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isSessionRunning = false
                print("DEBUG: ▶︎ Session stopped")
            }
        }
    }

    // MARK: - カウントダウン
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
        if #available(iOS 17.0, *) {
            settings.photoQualityPrioritization = .speed
        }

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

        sessionQueue.async {
            let isReady = self.session.isRunning && !self.session.inputs.isEmpty && !self.session.outputs.isEmpty

            guard isReady else {
                DispatchQueue.main.async {
                    print("DEBUG: ⚠️ capturePhoto skip (retry=\(retryCount))")
                }

                if retryCount < maxRetries {
                    self.startSession()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                        self?.internalCapturePhoto(settings: settings,
                                                   retryCount: retryCount + 1,
                                                   onFinish: onFinish)
                    }
                } else {
                    DispatchQueue.main.async {
                        print("DEBUG: ❌ capturePhoto 断念")
                        self.state = .error("撮影に失敗しました")
                        onFinish()
                    }
                }
                return
            }

            // captureは別キューへ
            self.captureQueue.async {
                let handler = PhotoCaptureHandler(
                    outputMaxDimension: self.shotMaxDimension,
                    forceUnmirror: false
                ) { [weak self] image in
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
                self.photoOutput.capturePhoto(with: settings, delegate: handler)
            }
        }
    }

    // MARK: - 4方向シーケンス制御
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

        if permissionDenied {
            state = .permissionDenied
        } else {
            state = .ready
        }
    }

    private func announceAndCountdownForCurrent() {
        let seconds = (currentDirection == .front) ? 15 : 10

        VoiceGuide.shared.speak("\(currentDirection.instruction)\(seconds)秒後に撮影します。")

        startCountdown(seconds: seconds, onTick: { sec in
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
                guard let img = self.capturedImage else {
                    self.isSequencing = false
                    return
                }

                // 重要：ここに入るimgはPhotoCaptureHandlerで縮小済み
                let shot = CapturedShot(direction: self.currentDirection, image: img)
                self.shots.append(shot)

                // 一時領域を即解放（重要）
                self.capturedImage = nil

                if self.shots.count >= 4 {
                    self.isSequencing = false
                    // 遷移前に止める（View側も保険で止める）
                    self.stopSession()
                    return
                }

                self.currentDirection = PostureShotDirection(rawValue: self.shots.count) ?? .left
                self.announceAndCountdownForCurrent()
            }
        }
    }
}
