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
                self.isSessionRunning = true
                print("DEBUG: ▶︎ Session running")
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

    // MARK: - 撮影（PhotoCaptureHandler を使用）
    func capturePhoto(onFinish: @escaping () -> Void) {
        print("DEBUG: 📸 VM.capturePhoto()")

        let settings = AVCapturePhotoSettings()

        // 既存のハンドラを一旦クリア
        photoHandler = nil

        // 強参照で保持するハンドラを生成
        let handler = PhotoCaptureHandler { [weak self] image in
            guard let self else { return }

            DispatchQueue.main.async {
                if let img = image {
                    print("DEBUG: 🟩 撮影成功 → image.size=\(img.size)")

                    // 元の向きを保ったまま「左右だけ」反転
                    let mirrored = img.mirroredHorizontally()
                    self.capturedImage = mirrored

                } else {
                    print("DEBUG: ❌ 撮影画像 nil（PhotoCaptureHandler から）")
                }

                // 撮影完了後はハンドラ参照を解放
                self.photoHandler = nil

                onFinish()
            }
        }

        // ハンドラをプロパティに保持してから capturePhoto を呼ぶ
        self.photoHandler = handler
        photoOutput.capturePhoto(with: settings, delegate: handler)
    }
}

// MARK: - UIImage ユーティリティ（左右反転）
private extension UIImage {
    /// 画像の向きは維持したまま、「見た目」だけ左右反転した UIImage を返す
    func mirroredHorizontally() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            guard let ctx = UIGraphicsGetCurrentContext() else {
                draw(in: CGRect(origin: .zero, size: size))
                return
            }

            // 右方向に width 分平行移動 → x を -1 倍にして左右反転
            ctx.translateBy(x: size.width, y: 0)
            ctx.scaleBy(x: -1, y: 1)

            draw(in: CGRect(origin: .zero, size: size))
        }
        return image
    }
}
