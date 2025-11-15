import Foundation
import AVFoundation
import UIKit

final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {

    private let onPhotoCaptured: (UIImage?) -> Void

    init(onPhotoCaptured: @escaping (UIImage?) -> Void) {
        self.onPhotoCaptured = onPhotoCaptured
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {

        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)
        else {
            onPhotoCaptured(nil)
            return
        }

        onPhotoCaptured(image)
    }
}
