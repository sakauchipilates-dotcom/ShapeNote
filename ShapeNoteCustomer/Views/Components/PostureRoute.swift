import UIKit

// NavigationStack 用に Hashable 必須
enum PostureRoute: Hashable {

    case guide
    case camera

    // UIImage を持つ場合 → 自前で Hashable / Equatable を実装する
    case flow(UIImage)
    case result(captured: UIImage, result: PostureResult, skeleton: UIImage, report: UIImage)

    // MARK: - Equatable
    static func == (lhs: PostureRoute, rhs: PostureRoute) -> Bool {
        switch (lhs, rhs) {
        case (.guide, .guide),
             (.camera, .camera):
            return true

        case (.flow, .flow):
            return true   // 画像比較はしない

        case (.result, .result):
            return true   // 内容比較は不要（画面が遷移できればOK）

        default:
            return false
        }
    }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        switch self {
        case .guide:
            hasher.combine("guide")

        case .camera:
            hasher.combine("camera")

        case .flow:
            hasher.combine("flow")

        case .result:
            hasher.combine("result")
        }
    }
}
