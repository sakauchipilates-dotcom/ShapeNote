import Foundation
import Vision
import FirebaseFirestore
import FirebaseAuth
import UIKit
import Combine

// MARK: - 結果モデル
struct PostureResult {
    let score: Double
    let message: String
}

// MARK: - 姿勢解析＋骨格描画＋診断書生成
final class PostureAnalyzer: ObservableObject {

    @Published var analysisResult: PostureResult?

    private let sequenceHandler = VNSequenceRequestHandler()
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
    // MARK: - (0) カラダの全関節ポイントを取得する（今回の最重要部分）
    // =================================================================
    func detectBodyPoints(in image: UIImage) throws -> [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint] {

        // Vision 用にサイズを最大 1080px にリサイズ（アスペクト比維持）
        let visionImage = image.resizedForVision(maxDimension: 1080)
        print("DEBUG: Vision input size = \(visionImage.size)")

        guard let cgImage = visionImage.cgImage else {
            throw NSError(
                domain: "Pose",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "画像を読み込めません"]
            )
        }

        let request = VNDetectHumanBodyPoseRequest()
        // orientation は fixedForFrontCamera / resizedForVision 側で .up にそろえている想定
        let handler = VNImageRequestHandler(cgImage: cgImage,
                                            orientation: .up,
                                            options: [:])
        try handler.perform([request])

        guard let obs = request.results?.first else {
            throw NSError(
                domain: "Pose",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "姿勢を検出できません"]
            )
        }

        let allPoints = try obs.recognizedPoints(.all)

        // 信頼度が低いものを除外
        let filtered: [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint] =
            allPoints.filter { $0.value.confidence > 0.1 }

        return filtered
    }

    // =================================================================
    // MARK: - (1) AI 姿勢解析
    // =================================================================
    func analyze(image: UIImage) async throws -> (PostureResult, AnalysisMetrics) {

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
            await MainActor.run { self.analysisResult = fallback }
            return (fallback, AnalysisMetrics(
                shoulderDiff: 0, hipDiff: 0,
                torsoTiltDeg: 0, headOffsetX: 0,
                kneeDiff: 0, ankleDiff: 0
            ))
        }

        // Optional joints
        let neck   = points[.neck]
        let lKnee  = points[.leftKnee]
        let rKnee  = points[.rightKnee]
        let lAnkle = points[.leftAnkle]
        let rAnkle = points[.rightAnkle]

        // 解析指標
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

        // スコア化
        func norm(_ v: CGFloat, threshold: CGFloat) -> CGFloat {
            min(1, max(0, v / threshold))
        }

        // 正規化した各指標
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
        await MainActor.run { self.analysisResult = result }

        return (result, metrics)
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
    // MARK: - (3) 骨格描画
    // =================================================================
    func drawSkeleton(on image: UIImage) throws -> UIImage {

        let points = try detectBodyPoints(in: image)
        let size = image.size

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in

            // 元画像
            image.draw(in: CGRect(origin: .zero, size: size))

            let cg = ctx.cgContext
            cg.setLineWidth(6)
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

            // 線（Bone）
            for (a, b) in lines {
                guard
                    let p1 = points[a], p1.confidence > 0.3,
                    let p2 = points[b], p2.confidence > 0.3
                else { continue }

                cg.move(to: pt(p1))
                cg.addLine(to: pt(p2))
                cg.strokePath()
            }

            // ポイントを描画
            cg.setFillColor(UIColor.systemYellow.cgColor)
            for (_, p) in points where p.confidence > 0.3 {
                let pos = pt(p)
                cg.fillEllipse(in: CGRect(x: pos.x - 8, y: pos.y - 8, width: 16, height: 16))
            }
        }
    }

    // =================================================================
    // MARK: - (4) 診断書生成（レポート画像）
    // =================================================================
    func generateReportImage(from skeleton: UIImage, result: PostureResult) -> UIImage {

        let canvasSize = CGSize(width: 1080, height: 1600)

        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { ctx in

            let context = ctx.cgContext

            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: canvasSize))

            // タイトル
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

            let comment = result.message
            comment.draw(
                in: CGRect(x: 500, y: 260, width: 500, height: 500),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 32),
                    .foregroundColor: UIColor.darkGray
                ]
            )
        }
    }
}

// =====================================================
// MARK: - UIImage ヘルパー（Vision 用リサイズ）
// =====================================================
private extension UIImage {

    /// Vision 用に、最大辺が maxDimension を超える場合だけ
    /// アスペクト比を保ったまま縮小する
    func resizedForVision(maxDimension: CGFloat = 1080) -> UIImage {

        let width  = size.width
        let height = size.height
        let maxSide = max(width, height)

        // すでに十分小さい場合はそのまま返す
        guard maxSide > maxDimension else { return self }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: width * scale, height: height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let result = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return result
    }
}
