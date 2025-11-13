import Foundation
import FirebaseFirestore

struct ContactItem: Identifiable {
    let id: String
    let name: String
    let message: String
    let status: String
    let timestamp: Timestamp
    let reply: String?
    let repliedAt: Timestamp?

    var timestampString: String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    var repliedAtString: String? {
        guard let repliedAt else { return nil }
        let date = repliedAt.dateValue()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
