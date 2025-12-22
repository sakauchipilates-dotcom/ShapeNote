import Foundation

/// 規約・プライバシーポリシーの「現在の版」
/// 変更したら、既存ユーザーにも再同意を強制できる（実務的）
enum LegalVersions {
    static let terms: String = "1.0"
    static let privacy: String = "1.0"
}

/// 表示先URL（あなたの公開URLに差し替え）
enum LegalURLs {
    static let terms = URL(string: "https://example.com/terms")!
    static let privacy = URL(string: "https://example.com/privacy")!
}

/// Firestore格納キー（必要なら将来変更しやすいように一箇所にまとめる）
enum LegalFirestoreKeys {
    static let collectionUsers = "users"
    static let agreedAt = "agreedAt"
    static let termsVersion = "termsVersion"
    static let privacyVersion = "privacyVersion"
}
