import Foundation

/// Firestore: /chats/{uid}/messages/{messageId}
public struct ChatMessage: Identifiable, Codable, Equatable {
    public var id: String                 // 常に一意（non-optional）
    public var text: String
    public var senderName: String
    public var senderIsAdmin: Bool
    public var timestamp: Date

    public init(
        id: String = UUID().uuidString,   // 生成時に必ずUUID付与
        text: String,
        senderName: String,
        senderIsAdmin: Bool,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.senderName = senderName
        self.senderIsAdmin = senderIsAdmin
        self.timestamp = timestamp
    }
}
