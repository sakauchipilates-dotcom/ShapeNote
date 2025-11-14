import SwiftUI

/// 姿勢分析フロー専用のナビゲーション管理クラス
final class PostureNavigation: ObservableObject {

    /// NavigationStack の path
    @Published var path: [PostureRoute] = []

    // MARK: - 各画面への遷移

    func pushGuide() {
        path.append(.guide)
    }

    func pushCamera() {
        path.append(.camera)
    }

    func pushFlow(image: UIImage) {
        path.append(.flow(image))
    }

    func pushResult(
        captured: UIImage,
        result: PostureResult,
        skeleton: UIImage,
        report: UIImage
    ) {
        path.append(.result(
            capturedImage: captured,
            result: result,
            skeleton: skeleton,
            report: report
        ))
    }

    /// 1つ戻る
    func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    /// ルートまで戻る（姿勢分析終了）
    func popToRoot() {
        path.removeAll()
    }
}
