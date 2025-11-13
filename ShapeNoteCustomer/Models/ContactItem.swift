import Foundation
import FirebaseFirestore

struct ContactItem: Identifiable, Codable {
    var id: String
    var name: String
    var message: String
    var status: String
    var timestamp: Timestamp
    var reply: String?
    var repliedAt: Timestamp?

    // 🔹 日時文字列を整形
    var timestampString: String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    var repliedAtString: String? {
        guard let repliedAt = repliedAt else { return nil }
        let date = repliedAt.dateValue()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
