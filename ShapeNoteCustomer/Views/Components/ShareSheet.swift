import SwiftUI
import UIKit

/// iOS 標準の共有シート（UIActivityViewController）をラップした View。
///
/// 画像・PDF・テキストなどをまとめて渡すと、
/// LINE / メール / ファイル保存 などのアクションをユーザーに選択させることができる。
struct ShareSheet: UIViewControllerRepresentable {

    /// 共有対象のアイテム（UIImage, URL, String, Data など）
    let items: [Any]

    /// 追加のカスタムアクティビティ（通常は nil でOK）
    let activities: [UIActivity]? = nil

    /// 非表示にしたい標準アクティビティの種類
    let excludedActivityTypes: [UIActivity.ActivityType]? = nil

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(
            activityItems: items,
            applicationActivities: activities
        )
        vc.excludedActivityTypes = excludedActivityTypes
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 共有中に動的に更新する必要はないため、特に処理なし
    }
}
