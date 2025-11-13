import Foundation

/// 管理アプリ用：来店履歴モデル
struct VisitHistoryItem: Identifiable, Hashable {
    let id = UUID()
    var date: String
    var note: String
    var productName: String?
    var price: Int?

    // Firestoreからの変換
    static func from(dict: [String: Any]) -> VisitHistoryItem? {
        guard let date = dict["date"] as? String,
              let note = dict["note"] as? String else { return nil }

        return VisitHistoryItem(
            date: date,
            note: note,
            productName: dict["productName"] as? String,
            price: dict["price"] as? Int
        )
    }

    // Firestore登録用Dictionary
    func toDictionary() -> [String: Any] {
        return [
            "date": date,
            "note": note,
            "productName": productName ?? "",
            "price": price ?? 0
        ]
    }
}
