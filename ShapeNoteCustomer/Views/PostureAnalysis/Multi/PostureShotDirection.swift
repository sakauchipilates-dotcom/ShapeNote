import Foundation
import UIKit

enum PostureShotDirection: Int, CaseIterable, Equatable {
    case front = 0
    case right
    case back
    case left

    var title: String {
        switch self {
        case .front: return "正面"
        case .right: return "右"
        case .back:  return "背面"
        case .left:  return "左"
        }
    }

    /// 撮影前にユーザーへ言う文言（向きの指示）
    var instruction: String {
        switch self {
        case .front: return "正面を撮影します。"
        case .right: return "右を向いてください。"
        case .back:  return "背面を向いてください。"
        case .left:  return "左を向いてください。"
        }
    }
}

/// 4方向の撮影結果（Flow/Hubで使う）
struct CapturedShot: Identifiable, Equatable {
    let id = UUID()
    let direction: PostureShotDirection
    let image: UIImage

    /// UIImage は Equatable ではないので、同一性は id で判定（UI更新・遷移用途として十分）
    static func == (lhs: CapturedShot, rhs: CapturedShot) -> Bool {
        lhs.id == rhs.id
    }
}
