import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.setup(session: session)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        DispatchQueue.main.async {
            uiView.updateFrame()
            uiView.updateMirroringIfNeeded()
        }
    }
}

final class PreviewView: UIView {

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    func setup(session: AVCaptureSession) {
        videoPreviewLayer.session = session
        videoPreviewLayer.videoGravity = .resizeAspectFill
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
        updateMirroringIfNeeded()
    }

    func updateFrame() {
        videoPreviewLayer.frame = bounds
    }

    /// 前面カメラのプレビューだけ「鏡」表示にする（写真はVM側で非ミラー）
    func updateMirroringIfNeeded() {
        guard let conn = videoPreviewLayer.connection else { return }

        // ★ここが重要：自動調整を切ってから手動で触る
        if conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = true
        }

        // iOS17以降は videoOrientation 非推奨だが、既存互換として残してOK
        if conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }
    }
}
