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

        if let data = photo.fileDataRepresentation(),
           let image = UIImage(data: data) {

            onCaptured(image)

        } else {
            print("DEBUG: PhotoCaptureHandler → 画像生成に失敗")
            onCaptured(nil)
        }
    }
}
