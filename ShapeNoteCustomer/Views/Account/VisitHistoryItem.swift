import Foundation

struct VisitHistoryItem: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var date: String
    var note: String
    var productName: String?
    var price: Int?

    // FirestoreのDictionaryからデコード
    static func from(dict: [String: Any]) -> VisitHistoryItem? {
        let date = dict["date"] as? String ?? ""
        let note = dict["note"] as? String ?? ""
        let productName = dict["productName"] as? String
        let price = dict["price"] as? Int
        return VisitHistoryItem(date: date, note: note, productName: productName, price: price)
    }
}
