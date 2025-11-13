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

final class PostureAnalyzer: ObservableObject {
    @Published var analysisResult: PostureResult?

    private let sequenceHandler = VNSequenceRequestHandler()
    private let db = Firestore.firestore()

    // MARK: - 画像を解析（複数関節ベース）
    func analyze(image: UIImage) async throws -> PostureResult {
        // まず関節データをまとめて取得
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
            await MainActor.run {
                self.analysisResult = fallback
            }
            return fallback
        }

        // 追加で取れる関節（あれば使う）
        let neck   = points[.neck]
        let lKnee  = points[.leftKnee]
        let rKnee  = points[.rightKnee]
        let lAnkle = points[.leftAnkle]
        let rAnkle = points[.rightAnkle]

        // MARK: 指標計算（Vision座標系: (0,0)=左下）

        // 肩と骨盤の左右差（左右バランス）
        let shoulderDiffY = abs(lShoulder.y - rShoulder.y)
        let hipDiffY      = abs(lHip.y      - rHip.y)

        // 体幹の傾き角度（肩ライン）
        let dx = lShoulder.x - rShoulder.x
        let dy = lShoulder.y - rShoulder.y
        let torsoTiltDeg = abs(atan2(dy, dx) * 180 / .pi)  // 0° が理想

        // 頭の位置（首と骨盤の中点の左右ずれ）
        var headOffsetX: CGFloat = 0
        if let neck = neck {
            let midHipX = (lHip.x + rHip.x) / 2.0
            headOffsetX = abs(neck.x - midHipX)
        }

        // 膝・足首の左右差
        var kneeDiffY: CGFloat = 0
        if let lKnee = lKnee, let rKnee = rKnee {
            kneeDiffY = abs(lKnee.y - rKnee.y)
        }
        var ankleDiffY: CGFloat = 0
        if let lAnkle = lAnkle, let rAnkle = rAnkle {
            ankleDiffY = abs(lAnkle.y - rAnkle.y)
        }

        // MARK: 正規化（0.0 = 理想, 1.0 = かなり悪い）
        func norm(_ v: CGFloat, threshold: CGFloat) -> CGFloat {
            min(1.0, max(0.0, v / threshold))
        }

        let shoulderPenalty = norm(shoulderDiffY, threshold: 0.10)   // 10% 高さ差で最大
        let hipPenalty      = norm(hipDiffY,      threshold: 0.10)
        let kneePenalty     = norm(kneeDiffY,     threshold: 0.12)
        let anklePenalty    = norm(ankleDiffY,    threshold: 0.12)
        let torsoPenalty    = norm(CGFloat(torsoTiltDeg), threshold: 8.0)   // 8°以上で最大
        let headPenalty     = norm(headOffsetX,   threshold: 0.08)

        // 重み付き平均（合計1.0になるようにする）
        let weightedPenalty =
            0.25 * shoulderPenalty +
            0.20 * hipPenalty +
            0.15 * torsoPenalty +
            0.15 * headPenalty +
            0.15 * kneePenalty +
            0.10 * anklePenalty

        let score = max(0, min(100, Int((1.0 - weightedPenalty) * 100)))

        // MARK: メッセージ生成
        let message: String
        switch score {
        case 90...100:
            message = "とても良い姿勢です！この状態をキープしていきましょう。"
        case 75..<90:
            message = "おおむね良好です。肩と骨盤の左右差を少し意識するとさらに安定します。"
        case 60..<75:
            message = "少し傾きが見られます。肩・骨盤・膝の高さを鏡で確認して整えてみましょう。"
        default:
            message = "全体的にバランスが崩れています。足元から頭まで一直線になる意識で立ってみましょう。"
        }

        let result = PostureResult(score: Double(score), message: message)

        // ObservableObject 経由でUIにも流せるようにしておく
        await MainActor.run {
            self.analysisResult = result
        }

        return result
    }

    // MARK: - Firestoreに結果だけ保存
    func saveResult(_ result: PostureResult) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ ログインユーザーなし。ローカル解析のみ。")
            return
        }

        let data: [String: Any] = [
            "score": result.score,
            "message": result.message,
            "timestamp": Timestamp(date: Date()),
            "privacy": [
                "rawImageStored": false,
                "processedOnDevice": true
            ]
        ]

        try await db
            .collection("users")
            .document(uid)
            .collection("postureResults")
            .addDocument(data: data)
    }

    // MARK: - 公開：骨格を描画した画像を作る
    /// 撮影画像の上に骨格ライン＆関節ポイントを描画した画像を返す
    func drawSkeleton(on image: UIImage) throws -> UIImage {
        let points = try detectBodyPoints(in: image)
        let size = image.size

        let renderer = UIGraphicsImageRenderer(size: size)
        let resultImage = renderer.image { context in
            // 元画像
            image.draw(in: CGRect(origin: .zero, size: size))

            let ctx = context.cgContext
            ctx.setLineWidth(6)
            ctx.setStrokeColor(UIColor.systemBlue.cgColor)
            ctx.setLineCap(.round)

            func imgPoint(_ p: VNRecognizedPoint) -> CGPoint {
                CGPoint(
                    x: CGFloat(p.x) * size.width,
                    y: (1.0 - CGFloat(p.y)) * size.height   // Visionの原点(左下) → UIKit(左上)
                )
            }

            // 骨格の接続ペア
            typealias Joint = VNHumanBodyPoseObservation.JointName
            let connections: [(Joint, Joint)] = [
                (.neck, .leftShoulder),
                (.neck, .rightShoulder),
                (.leftShoulder, .leftElbow),
                (.leftElbow, .leftWrist),
                (.rightShoulder, .rightElbow),
                (.rightElbow, .rightWrist),
                (.neck, .root),
                (.root, .leftHip),
                (.root, .rightHip),
                (.leftHip, .leftKnee),
                (.leftKnee, .leftAnkle),
                (.rightHip, .rightKnee),
                (.rightKnee, .rightAnkle)
            ]

            // ライン描画
            for (a, b) in connections {
                guard
                    let p1 = points[a], p1.confidence > 0.3,
                    let p2 = points[b], p2.confidence > 0.3
                else { continue }

                let pt1 = imgPoint(p1)
                let pt2 = imgPoint(p2)
                ctx.move(to: pt1)
                ctx.addLine(to: pt2)
                ctx.strokePath()
            }

            // 関節ポイント描画
            ctx.setFillColor(UIColor.systemYellow.cgColor)
            for (_, p) in points where p.confidence > 0.3 {
                let pt = imgPoint(p)
                let r: CGFloat = 8
                let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
                ctx.fillEllipse(in: rect)
            }
        }

        return resultImage
    }

    // MARK: - 公開：結果シート画像を作る
    /// 骨格描画済み画像＋スコア＋コメントを 1 枚の「結果シート画像」として返す
    func generateReportImage(from skeletonImage: UIImage, result: PostureResult) -> UIImage {
        let baseSize = skeletonImage.size
        let bottomHeight: CGFloat = 220
        let totalSize = CGSize(width: baseSize.width,
                               height: baseSize.height + bottomHeight)

        let renderer = UIGraphicsImageRenderer(size: totalSize)
        let img = renderer.image { context in
            let ctx = context.cgContext

            // 背景
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(origin: .zero, size: totalSize))

            // 上部：骨格画像（横幅いっぱい）
            skeletonImage.draw(in: CGRect(x: 0,
                                          y: 0,
                                          width: baseSize.width,
                                          height: baseSize.height))

            // 下部：テキストエリア
            let inset: CGFloat = 24
            let textOriginY = baseSize.height + 20

            let title = "AI姿勢分析レポート"
            let scoreText = "スコア：\(Int(result.score)) / 100"
            let message = result.message

            let titleFont  = UIFont.boldSystemFont(ofSize: 22)
            let scoreFont  = UIFont.systemFont(ofSize: 18, weight: .medium)
            let bodyFont   = UIFont.systemFont(ofSize: 16)

            let paragraphCenter = NSMutableParagraphStyle()
            paragraphCenter.alignment = .center

            let paragraphLeft = NSMutableParagraphStyle()
            paragraphLeft.alignment = .left
            paragraphLeft.lineSpacing = 4

            // タイトル
            let titleAttr = NSAttributedString(
                string: title,
                attributes: [
                    .font: titleFont,
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraphCenter
                ]
            )
            let titleRect = CGRect(x: inset,
                                   y: textOriginY,
                                   width: totalSize.width - inset * 2,
                                   height: 28)
            titleAttr.draw(in: titleRect)

            // スコア
            let scoreAttr = NSAttributedString(
                string: scoreText,
                attributes: [
                    .font: scoreFont,
                    .foregroundColor: UIColor.darkGray,
                    .paragraphStyle: paragraphCenter
                ]
            )
            let scoreRect = CGRect(x: inset,
                                   y: textOriginY + 32,
                                   width: totalSize.width - inset * 2,
                                   height: 24)
            scoreAttr.draw(in: scoreRect)

            // 本文メッセージ
            let messageAttr = NSAttributedString(
                string: message,
                attributes: [
                    .font: bodyFont,
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraphLeft
                ]
            )
            let msgRect = CGRect(x: inset,
                                 y: textOriginY + 64,
                                 width: totalSize.width - inset * 2,
                                 height: bottomHeight - 80)
            messageAttr.draw(in: msgRect)
        }

        return img
    }

    // MARK: - Helper: 関節検出を共通化
    private func detectBodyPoints(
        in image: UIImage
    ) throws -> [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] {

        guard let cgImage = image.cgImage else {
            throw NSError(
                domain: "PostureAnalyzer",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "CGImageの取得に失敗"]
            )
        }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: cgImagePropertyOrientation(from: image.imageOrientation)
        )
        try handler.perform([request])

        guard
            let observations = request.results as? [VNHumanBodyPoseObservation],
            let obs = observations.first
        else {
            throw NSError(
                domain: "PostureAnalyzer",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "姿勢を検出できませんでした"]
            )
        }

        let points = try obs.recognizedPoints(.all)
        return points
    }

    // MARK: - Helper: 画像向き
    private func cgImagePropertyOrientation(
        from uiOrientation: UIImage.Orientation
    ) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
}
