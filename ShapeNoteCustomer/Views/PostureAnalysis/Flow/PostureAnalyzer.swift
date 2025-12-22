import Foundation
import Vision
import FirebaseFirestore
import FirebaseAuth
import UIKit
import Combine
import ImageIO

// MARK: - 結果モデル
struct PostureResult {
    let score: Double
    let message: String
}

// MARK: - 姿勢解析＋骨格描画＋診断書生成
final class PostureAnalyzer: ObservableObject {

    @Published var analysisResult: PostureResult?

    private let db = Firestore.firestore()

    // MARK: - 内部メトリクス
    struct AnalysisMetrics {
        let shoulderDiff: CGFloat
        let hipDiff: CGFloat
        let torsoTiltDeg: CGFloat
        let headOffsetX: CGFloat
        let kneeDiff: CGFloat
        let ankleDiff: CGFloat
    }

    // =================================================================
    // MARK: - (0) 関節ポイント取得（メモリ安全）
    // =================================================================
    func detectBodyPoints(in image: UIImage,
                          maxDimension: CGFloat = 1080) throws -> [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint] {

        // 解析前に縮小+orientation統一（入力が大きいとここで落ちやすい）
        let visionImage = image
            .downsampled(maxDimension: maxDimension)
            .normalizedOrientation()

        print("DEBUG: Vision input size = \(visionImage.size)")

        guard let cgImage = visionImage.cgImage else {
            throw NSError(domain: "Pose", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "画像を読み込めません"])
        }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try handler.perform([request])

        guard let obs = request.results?.first else {
            throw NSError(domain: "Pose", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "姿勢を検出できません"])
        }

        let allPoints = try obs.recognizedPoints(.all)
        return allPoints.filter { $0.value.confidence > 0.1 }
    }

    // =================================================================
    // MARK: - (1) AI 姿勢解析（同期版：detachedで扱いやすい）
    // =================================================================
    func analyzeSync(image: UIImage) throws -> (PostureResult, AnalysisMetrics) {

        let points = try detectBodyPoints(in: image)

        guard
            let lShoulder = points[.leftShoulder],
            let rShoulder = points[.rightShoulder],
            let lHip      = points[.leftHip],
            let rHip      = points[.rightHip]
        else {
            let fallback = PostureResult(
                score: 0,
                message: "姿勢を認識できませんでした。全身が映るように撮影してください。"
            )
            let metrics = AnalysisMetrics(shoulderDiff: 0, hipDiff: 0, torsoTiltDeg: 0, headOffsetX: 0, kneeDiff: 0, ankleDiff: 0)
            DispatchQueue.main.async { self.analysisResult = fallback }
            return (fallback, metrics)
        }

        let neck   = points[.neck]
        let lKnee  = points[.leftKnee]
        let rKnee  = points[.rightKnee]
        let lAnkle = points[.leftAnkle]
        let rAnkle = points[.rightAnkle]

        let shoulderDiffY = abs(lShoulder.y - rShoulder.y)
        let hipDiffY      = abs(lHip.y      - rHip.y)

        let dx = lShoulder.x - rShoulder.x
        let dy = lShoulder.y - rShoulder.y
        let torsoTiltDeg = abs(atan2(dy, dx) * 180 / .pi)

        var headOffsetX: CGFloat = 0
        if let neck = neck {
            headOffsetX = abs(neck.x - (lHip.x + rHip.x) / 2)
        }

        let kneeDiffY  = (lKnee  != nil && rKnee  != nil) ? abs(lKnee!.y  - rKnee!.y)  : 0
        let ankleDiffY = (lAnkle != nil && rAnkle != nil) ? abs(lAnkle!.y - rAnkle!.y) : 0

        let metrics = AnalysisMetrics(
            shoulderDiff: shoulderDiffY,
            hipDiff: hipDiffY,
            torsoTiltDeg: torsoTiltDeg,
            headOffsetX: headOffsetX,
            kneeDiff: kneeDiffY,
            ankleDiff: ankleDiffY
        )

        func norm(_ v: CGFloat, threshold: CGFloat) -> CGFloat {
            min(1, max(0, v / threshold))
        }

        let w1 = 0.25 * norm(shoulderDiffY, threshold: 0.1)
        let w2 = 0.20 * norm(hipDiffY,      threshold: 0.1)
        let w3 = 0.15 * norm(torsoTiltDeg,  threshold: 8.0)
        let w4 = 0.15 * norm(headOffsetX,   threshold: 0.08)
        let w5 = 0.15 * norm(kneeDiffY,     threshold: 0.12)
        let w6 = 0.10 * norm(ankleDiffY,    threshold: 0.12)

        let rawScore = 1.0 - (w1 + w2 + w3 + w4 + w5 + w6)
        let clamped = max(0, min(1, rawScore))
        let scoreValue = Int(clamped * 100)

        let message: String
        switch scoreValue {
        case 90...100: message = "とても良い姿勢です！この状態をキープしていきましょう。"
        case 75..<90:  message = "おおむね良好です。肩と骨盤の左右差を少し意識するとさらに安定します。"
        case 60..<75:  message = "少し傾きが見られます。肩・骨盤・膝の高さを確認して整えてみましょう。"
        default:       message = "全体的にバランスが崩れています。足元から頭まで一直線になる意識で立ってみましょう。"
        }

        let result = PostureResult(score: Double(scoreValue), message: message)
        DispatchQueue.main.async { self.analysisResult = result }
        return (result, metrics)
    }

    // 既存互換（呼び出し側がasyncでもOK）
    func analyze(image: UIImage) async throws -> (PostureResult, AnalysisMetrics) {
        return try analyzeSync(image: image)
    }

    // =================================================================
    // MARK: - (2) Firestore 保存
    // =================================================================
    func saveResult(_ result: PostureResult) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        try await db.collection("users")
            .document(uid)
            .collection("postureResults")
            .addDocument(data: [
                "score": result.score,
                "message": result.message,
                "timestamp": Timestamp(date: Date())
            ])
    }

    // =================================================================
    // MARK: - (3) 骨格描画（入力画像サイズで描く：縮小画像前提）
    // =================================================================
    func drawSkeleton(on image: UIImage) throws -> UIImage {

        let base = image.normalizedOrientation()
        let points = try detectBodyPoints(in: base, maxDimension: 1080)
        let size = base.size

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            base.draw(in: CGRect(origin: .zero, size: size))

            let cg = ctx.cgContext
            cg.setLineWidth(5)
            cg.setStrokeColor(UIColor.systemBlue.cgColor)
            cg.setLineCap(.round)

            func pt(_ p: VNRecognizedPoint) -> CGPoint {
                CGPoint(x: CGFloat(p.x) * size.width,
                        y: (1 - CGFloat(p.y)) * size.height)
            }

            typealias J = VNHumanBodyPoseObservation.JointName
            let lines: [(J, J)] = [
                (.neck, .leftShoulder), (.neck, .rightShoulder),
                (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
                (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
                (.neck, .root),
                (.root, .leftHip), (.root, .rightHip),
                (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
                (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
            ]

            for (a, b) in lines {
                guard
                    let p1 = points[a], p1.confidence > 0.3,
                    let p2 = points[b], p2.confidence > 0.3
                else { continue }

                cg.move(to: pt(p1))
                cg.addLine(to: pt(p2))
                cg.strokePath()
            }

            cg.setFillColor(UIColor.systemYellow.cgColor)
            for (_, p) in points where p.confidence > 0.3 {
                let pos = pt(p)
                cg.fillEllipse(in: CGRect(x: pos.x - 6, y: pos.y - 6, width: 12, height: 12))
            }
        }
    }

    // =================================================================
    // MARK: - (4) 診断書生成
    // =================================================================
    func generateReportImage(from skeleton: UIImage, result: PostureResult) -> UIImage {

        let canvasSize = CGSize(width: 1080, height: 1600)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { ctx in

            let context = ctx.cgContext
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: canvasSize))

            let title = "姿勢分析レポート"
            title.draw(
                at: CGPoint(x: 60, y: 60),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 48),
                    .foregroundColor: UIColor.black
                ]
            )

            skeleton.draw(in: CGRect(x: 60, y: 150, width: 400, height: 600))

            let scoreText = "総合スコア：\(Int(result.score))点"
            scoreText.draw(
                at: CGPoint(x: 500, y: 200),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 42),
                    .foregroundColor: UIColor.darkGray
                ]
            )

            result.message.draw(
                in: CGRect(x: 500, y: 260, width: 520, height: 520),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 32),
                    .foregroundColor: UIColor.darkGray
                ]
            )
        }
    }
}

// =====================================================
// MARK: - UIImage helpers（downsample / normalize）
// =====================================================
private extension UIImage {

    func downsampled(maxDimension: CGFloat) -> UIImage {
        guard max(size.width, size.height) > maxDimension else { return self }
        guard let data = self.jpegData(compressionQuality: 0.9) else { return self }

        let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOpts as CFDictionary) else { return self }

        let downOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, downOpts as CFDictionary) else { return self }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }

    func normalizedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
