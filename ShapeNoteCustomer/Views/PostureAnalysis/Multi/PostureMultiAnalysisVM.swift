import Foundation
import UIKit
import Combine
import ImageIO

@MainActor
final class PostureMultiAnalysisVM: ObservableObject {

    struct Item: Identifiable {
        let id = UUID()
        let shot: CapturedShot

        var original: UIImage { shot.image }
        var direction: PostureShotDirection { shot.direction }

        var skeletonImage: UIImage? = nil
        var score: Int? = nil
        var message: String? = nil
        var metrics: PostureAnalyzer.AnalysisMetrics? = nil
        var errorText: String? = nil
    }

    @Published var items: [Item] = []
    @Published var isLoading: Bool = false
    @Published var progressText: String = ""

    @Published var summaryScore: Int? = nil
    @Published var summaryMessage: String = ""
    @Published var summaryHeadline: String = "解析中…"
    @Published var summaryBullets: [String] = []

    private let analysisMaxDimension: CGFloat = 1080
    private let skeletonMaxDimension: CGFloat = 1080

    init(shots: [CapturedShot]) {
        let ordered = PostureShotDirection.allCases.compactMap { dir in
            shots.first(where: { $0.direction == dir })
        }
        self.items = ordered.map { Item(shot: $0) }
    }

    func start() {
        guard !items.isEmpty else { return }

        isLoading = true
        progressText = "解析を開始します…"
        summaryScore = nil
        summaryMessage = ""
        summaryHeadline = "解析中…"
        summaryBullets = []

        Task { await analyzeAllSequential() }
    }

    func primaryMetricChips(for item: Item) -> [String] {
        guard let m = item.metrics else { return [] }
        return [
            "肩 \(fmt(m.shoulderDiff))",
            "骨盤 \(fmt(m.hipDiff))",
            "体幹 \(Int(m.torsoTiltDeg))°",
            "頭 \(fmt(m.headOffsetX))"
        ]
    }

    private func analyzeAllSequential() async {
        var working = items
        progressText = "4方向を解析中…"

        for idx in working.indices {
            let dirTitle = working[idx].direction.title
            progressText = "\(dirTitle) を解析中…"

            let baseForAnalysis = working[idx].original
                .downsampled(maxDimension: analysisMaxDimension)
                .normalizedOrientation()

            let baseForSkeleton = baseForAnalysis
                .downsampled(maxDimension: skeletonMaxDimension)
                .normalizedOrientation()

            do {
                let output = try await Task.detached(priority: .userInitiated) { () throws -> (Int, String, PostureAnalyzer.AnalysisMetrics, UIImage) in
                    try autoreleasepool {
                        let analyzer = PostureAnalyzer()
                        let (result, metrics) = try analyzer.analyzeSync(image: baseForAnalysis)
                        let skel = try analyzer.drawSkeleton(on: baseForSkeleton)
                        return (Int(result.score), result.message, metrics, skel)
                    }
                }.value

                working[idx].score = output.0
                working[idx].message = output.1
                working[idx].metrics = output.2
                working[idx].skeletonImage = output.3
                working[idx].errorText = nil

            } catch {
                working[idx].errorText = "解析に失敗しました（\(dirTitle)）"
                working[idx].score = nil
                working[idx].message = nil
                working[idx].metrics = nil
                working[idx].skeletonImage = nil
            }

            self.items = working
        }

        buildSummary(from: working)

        isLoading = false
        progressText = ""
    }

    private func buildSummary(from items: [Item]) {
        let scores = items.compactMap { $0.score }
        if scores.isEmpty {
            summaryScore = nil
            summaryHeadline = "解析できませんでした"
            summaryMessage = "全身が映る距離で、明るい場所で再撮影してください。"
            summaryBullets = ["顔〜足先までが画面内に入る距離で撮影", "逆光を避ける", "可能なら三脚固定"]
            return
        }

        let avg = Int(Double(scores.reduce(0, +)) / Double(scores.count))
        summaryScore = avg

        switch avg {
        case 90...100:
            summaryHeadline = "全体として良好です"
        case 75..<90:
            summaryHeadline = "概ね良好ですが、軽微な偏りがあります"
        case 60..<75:
            summaryHeadline = "偏りが見られます"
        default:
            summaryHeadline = "全体的にバランスの崩れが目立ちます"
        }

        var findings: [String] = []
        var bullets: [String] = []

        if let m = items.first(where: { $0.direction == .front })?.metrics {
            if m.shoulderDiff > 0.06 { findings.append("肩の左右差") }
            if m.hipDiff > 0.06 { findings.append("骨盤の左右差") }
            if m.kneeDiff > 0.08 { findings.append("膝の左右差") }
        }
        if let m = items.first(where: { $0.direction == .back })?.metrics {
            if m.shoulderDiff > 0.06 { findings.append("肩の左右差") }
            if m.hipDiff > 0.06 { findings.append("骨盤の左右差") }
        }

        func sideFinding(_ m: PostureAnalyzer.AnalysisMetrics) {
            if m.torsoTiltDeg > 6.0 { findings.append("体幹の傾き") }
            if m.headOffsetX > 0.05 { findings.append("頭部の前方偏位") }
        }
        if let m = items.first(where: { $0.direction == .right })?.metrics { sideFinding(m) }
        if let m = items.first(where: { $0.direction == .left })?.metrics { sideFinding(m) }

        findings = Array(NSOrderedSet(array: findings)) as? [String] ?? findings

        if findings.isEmpty {
            summaryMessage = "4方向の差は小さく、安定しています。現状維持を目標に、日常姿勢を整えていきましょう。"
            bullets = ["胸郭を引き上げて呼吸を深く", "片脚荷重を避ける", "肩をすくめない"]
        } else {
            summaryMessage = "特に「\(findings.joined(separator: "・"))」が目立ちます。まずは日常動作のクセを減らすことが優先です。"

            if findings.contains("肩の左右差") {
                bullets.append("バッグを片側だけで持つ癖を減らす")
            }
            if findings.contains("骨盤の左右差") {
                bullets.append("立位で片脚に体重を乗せない")
            }
            if findings.contains("体幹の傾き") {
                bullets.append("肋骨を上げ、骨盤の上に胸郭を積む意識")
            }
            if findings.contains("頭部の前方偏位") {
                bullets.append("顎を引いて後頭部を後ろへ“長く”保つ")
            }
        }

        summaryBullets = bullets
    }

    private func fmt(_ v: CGFloat) -> String {
        String(format: "%.2f", Double(v))
    }
}

// =====================================================
// MARK: - UIImage downsample（メモリ対策）
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
