import Foundation
import FirebaseFirestore

struct UserItem: Identifiable, Hashable {
    let id: String
    let name: String
    let email: String
    let gender: Gender
    let birthYear: Int?
    let joinedAt: Date?
    let iconURL: String?
    let membershipRank: Rank?
    let displayId: String?
    
    enum Gender: String, CaseIterable, Hashable {
        case male, female, unknown
        
        var label: String {
            switch self {
            case .male: return "男性"
            case .female: return "女性"
            case .unknown: return "不明"
            }
        }
    }
    
    enum Rank: String, CaseIterable, Hashable {
        case bronze = "Bronze"
        case silver = "Silver"
        case gold   = "Gold"
        
        var label: String {
            switch self {
            case .bronze: return "Bronze"
            case .silver: return "Silver"
            case .gold:   return "Gold"
            }
        }
    }
    
    var age: Int? {
        guard let year = birthYear else { return nil }
        let currentYear = Calendar.current.component(.year, from: Date())
        return currentYear - year
    }
}

// MARK: - Firestoreデータ → UserItem変換ヘルパ
extension UserItem {
    static func from(document: DocumentSnapshot) -> UserItem? {
        guard let data = document.data() else { return nil }
        
        let name = data["name"] as? String ?? "(無名)"
        let email = data["email"] as? String ?? ""
        
        let genderStr = (data["gender"] as? String ?? "").lowercased()
        let gender = Gender(rawValue: genderStr) ?? .unknown
        
        let birthYear = data["birthYear"] as? Int
        
        // Timestamp / ISO8601 どちらも対応
        var joinedDate: Date? = nil
        if let ts = data["joinedAt"] as? Timestamp {
            joinedDate = ts.dateValue()
        } else if let str = data["joinedAt"] as? String {
            joinedDate = ISO8601DateFormatter().date(from: str)
        }
        
        let iconURL = data["iconURL"] as? String
        let displayId = data["displayId"] as? String
        
        var rank: Rank? = nil
        if let r = data["membershipRank"] as? String {
            rank = Rank(rawValue: r)
        }
        
        return UserItem(
            id: document.documentID,
            name: name,
            email: email,
            gender: gender,
            birthYear: birthYear,
            joinedAt: joinedDate,
            iconURL: iconURL,
            membershipRank: rank,
            displayId: displayId
        )
    }
}
