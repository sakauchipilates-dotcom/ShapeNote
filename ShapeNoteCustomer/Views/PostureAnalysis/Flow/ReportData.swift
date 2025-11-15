import UIKit

/// 診断書用にまとめられた解析データ
struct ReportData {
    let capturedImage: UIImage
    let skeletonImage: UIImage

    let score: Int
    let message: String

    // 詳細指標
    let shoulderDiff: CGFloat
    let hipDiff: CGFloat
    let torsoTilt: CGFloat
    let headOffset: CGFloat
    let kneeDiff: CGFloat
    let ankleDiff: CGFloat

    let date: Date
}
