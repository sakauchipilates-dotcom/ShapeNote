import Foundation

/// Firestore内の `/chats/{uid}` に対応
public struct ChatItem: Identifiable, Codable {
    public var id: String?                   // uid（顧客UID）
    public var lastText: String              // 最後のメッセージ
    public var lastSenderName: String        // 最後の送信者名
    public var lastSenderIsAdmin: Bool       // 管理者送信かどうか
    public var updatedAt: Date               // 最終更新日時
    public var adminUnread: Bool             // 管理者未読
    public var userUnread: Bool              // 顧客未読

    public init(id: String? = nil,
                lastText: String = "",
                lastSenderName: String = "",
                lastSenderIsAdmin: Bool = false,
                updatedAt: Date = Date(),
                adminUnread: Bool = false,
                userUnread: Bool = false) {
        self.id = id
        self.lastText = lastText
        self.lastSenderName = lastSenderName
        self.lastSenderIsAdmin = lastSenderIsAdmin
        self.updatedAt = updatedAt
        self.adminUnread = adminUnread
        self.userUnread = userUnread
    }
}
