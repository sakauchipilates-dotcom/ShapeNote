import UIKit
import AVFoundation
import ImageIO

/// AVCapturePhotoCaptureDelegate を簡易に扱うためのヘルパークラス（メモリ安全版）
final class PhotoCaptureHandler: NSObject, AVCapturePhotoCaptureDelegate {

    private let onCaptured: (UIImage?) -> Void

    /// ここで縮小してからUIImage化する（shotsにフル解像度を残さない）
    private let outputMaxDimension: CGFloat

    /// フロントミラーを強制解除したい場合のみ true（通常は false 推奨）
    private let forceUnmirror: Bool

    init(outputMaxDimension: CGFloat = 1440,
         forceUnmirror: Bool = false,
         onCaptured: @escaping (UIImage?) -> Void) {
        self.outputMaxDimension = outputMaxDimension
        self.forceUnmirror = forceUnmirror
        self.onCaptured = onCaptured
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {

        if let error = error {
            print("DEBUG: PhotoCaptureHandler error = \(error)")
            onCaptured(nil)
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            print("DEBUG: PhotoCaptureHandler → fileDataRepresentation failed")
            onCaptured(nil)
            return
        }

        // 1) データ段階で縮小（フル解像度UIImage生成を避ける）
        guard let down = UIImage.downsampleFromJPEGData(data, maxPixel: Int(outputMaxDimension)) else {
            print("DEBUG: PhotoCaptureHandler → downsample failed")
            onCaptured(nil)
            return
        }

        // 2) orientation を .up に正規化
        var fixed = down.normalizedOrientation()

        // 3) mirrored のみ解除（もしくは強制解除）
        if forceUnmirror || fixed.isMirroredOrientation {
            fixed = fixed.unmirrored()
        }

        print("DEBUG: capture(out) size=\(fixed.size), orientation=\(fixed.imageOrientation.rawValue)")
        onCaptured(fixed)
    }
}

// =====================================================
// MARK: - UIImage helper（downsample / orientation / unmirror）
// =====================================================
private extension UIImage {

    static func downsampleFromJPEGData(_ data: Data, maxPixel: Int) -> UIImage? {
        let srcOpts: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOpts as CFDictionary) else {
            return nil
        }

        let downOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, downOpts as CFDictionary) else {
            return nil
        }

        // ここで.orientationはupに固定（以降の描画で統一）
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }

    var isMirroredOrientation: Bool {
        switch imageOrientation {
        case .upMirrored, .downMirrored, .leftMirrored, .rightMirrored:
            return true
        default:
            return false
        }
    }

    /// orientation を .up に統一（縮小後のサイズで呼ばれる想定）
    func normalizedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// 左右反転解除（縮小後のサイズで呼ばれる想定）
    func unmirrored() -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: size.width, y: 0)
            cg.scaleBy(x: -1, y: 1)
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
