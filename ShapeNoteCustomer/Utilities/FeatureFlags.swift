import Foundation

enum FeatureFlags {

    /// 姿勢分析 本体機能
    ///
    /// - DEBUG: 常に有効（開発者・デモ機・TestFlight内部テスト用）
    /// - RELEASE: 無効（ComingSoonOverlay 表示）
    static var postureAnalysisEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// レポート書き出し機能
    ///（将来 Export だけ段階解放したい場合に備えて分離）
    static var postureAnalysisExportEnabled: Bool {
        #if DEBUG
        return true
        #else
        return true
        #endif
    }
}
