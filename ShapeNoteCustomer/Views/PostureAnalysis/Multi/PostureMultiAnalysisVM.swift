import Foundation
import UIKit
import Combine

@MainActor
final class PostureMultiAnalysisVM: ObservableObject {

    struct Item: Identifiable, Equatable {
        let id = UUID()
        let shot: CapturedShot

        // 解析結果（とりあえず保持。後でUIに載せる）
        var score: Int? = nil
        var message: String? = nil
        var skeletonImage: UIImage? = nil
    }

    @Published var items: [Item] = []
    @Published var summaryText: String = "解析の準備中…"
    @Published var isAnalyzing: Bool = false

    private let analyzer = PostureAnalyzer()

    init(shots: [CapturedShot]) {
        self.items = shots.map { Item(shot: $0) }
    }

    /// 4枚を順番に解析（今は逐次。後で並列化も可）
    func runAllAnalyses() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        summaryText = "解析中…"

        Task {
            do {
                var scores: [Int] = []
                var messages: [String] = []

                for idx in items.indices {
                    let img = items[idx].shot.image

                    // (1) 骨格描画
                    let skel = try analyzer.drawSkeleton(on: img)

                    // (2) スコア等
                    let (result, _) = try await analyzer.analyze(image: img)
                    let score = Int(result.score)

                    items[idx].skeletonImage = skel
                    items[idx].score = score
                    items[idx].message = result.message

                    scores.append(score)
                    messages.append(result.message)
                }

                // 総評（ひとまず平均＋要約。後で精密に作り込めます）
                let avg = scores.isEmpty ? 0 : Int(Double(scores.reduce(0, +)) / Double(scores.count))
                summaryText = "総合スコア（平均）：\(avg)点\n\n" + messages.prefix(2).joined(separator: "\n")

                isAnalyzing = false
            } catch {
                summaryText = "解析に失敗しました：\(error.localizedDescription)"
                isAnalyzing = false
            }
        }
    }
}
