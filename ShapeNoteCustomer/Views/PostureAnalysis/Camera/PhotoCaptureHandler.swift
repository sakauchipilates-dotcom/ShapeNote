import UIKit
import AVFoundation

/// AVCapturePhotoCaptureDelegate を簡易に扱うためのヘルパークラス
final class PhotoCaptureHandler: NSObject, AVCapturePhotoCaptureDelegate {

    private let onCaptured: (UIImage?) -> Void

    init(onCaptured: @escaping (UIImage?) -> Void) {
        self.onCaptured = onCaptured
    }

    // 撮影完了時に呼ばれる
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {

        if let error = error {
            print("DEBUG: PhotoCaptureHandler error = \(error)")
            onCaptured(nil)
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("DEBUG: PhotoCaptureHandler → 画像生成に失敗")
            onCaptured(nil)
            return
        }

        print("DEBUG: raw capture size=\(image.size), orientation=\(image.imageOrientation.rawValue)")

        // フロントカメラ用に：
        //  - orientation を .up に正規化
        //  - mirror を解除（左右反転を元に戻す）
        let fixed = image.fixedForFrontCamera()

        print("DEBUG: fixed capture size=\(fixed.size), orientation=\(fixed.imageOrientation.rawValue)")

        onCaptured(fixed)
    }
}

// =====================================================
// MARK: - UIImage ヘルパー（orientation + mirror 補正）
// =====================================================
private extension UIImage {

    /// フロントカメラ撮影画像を
    ///  - orientation を .up に統一
    ///  - mirror を解除（左右反転を元に戻す）
    func fixedForFrontCamera() -> UIImage {

        let size = self.size

        // 1) orientation を .up に正規化
        let oriented = UIGraphicsImageRenderer(size: size).image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }

        // 2) フロントカメラの鏡像を解除するため、左右反転をかけ直す
        let unmirrored = UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext

            // x 軸方向に左右反転
            cg.translateBy(x: size.width, y: 0)
            cg.scaleBy(x: -1, y: 1)

            oriented.draw(in: CGRect(origin: .zero, size: size))
        }

        return unmirrored
    }
}
