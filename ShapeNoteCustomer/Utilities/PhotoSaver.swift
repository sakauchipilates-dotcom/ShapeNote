import Photos
import UIKit

enum PhotoSaveResult {
    case success
    case denied
    case failure(Error)
}

struct PhotoSaver {

    static func save(_ image: UIImage,
                     completion: @escaping (PhotoSaveResult) -> Void) {

        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {

        case .authorized, .limited:
            saveImage(image, completion: completion)

        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        saveImage(image, completion: completion)
                    } else {
                        completion(.denied)
                    }
                }
            }

        default:
            completion(.denied)
        }
    }

    private static func saveImage(_ image: UIImage,
                                  completion: @escaping (PhotoSaveResult) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else if success {
                    completion(.success)
                } else {
                    completion(.denied)
                }
            }
        }
    }
}
