import Foundation

enum FeatureFlags {

    // MARK: - 姿勢分析関連

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
    /// （将来 Export だけ段階解放したい場合に備えて分離）
    static var postureAnalysisExportEnabled: Bool {
        #if DEBUG
        return true
        #else
        // 本番でもレポート書き出し自体は許可
        return true
        #endif
    }

    // MARK: - サブスクリプション

    /// サブスクリプション機能の有効 / 無効
    ///
    /// - DEBUG: 有効（動作確認・デバッグ用）
    /// - RELEASE: 無効（初期リリースでは購入不可）
    #if DEBUG
    static let isSubscriptionEnabled: Bool = true
    #else
    static let isSubscriptionEnabled: Bool = false
    #endif

    // MARK: - コミュニティ

    /// コミュニティ機能の有効 / 無効
    ///
    /// - DEBUG: 有効（一覧・詳細のUI確認用）
    /// - RELEASE: 無効（初期リリースでは「準備中」表示のみ）
    #if DEBUG
    static let isCommunityEnabled: Bool = true
    #else
    static let isCommunityEnabled: Bool = false
    #endif
}
