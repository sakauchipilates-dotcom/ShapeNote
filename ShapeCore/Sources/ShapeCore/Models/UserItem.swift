import Foundation
import FirebaseFirestore

public struct UserItem: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let email: String
    public let gender: Gender
    public let birthYear: Int?
    public let joinedAt: Date?
    public let iconURL: String?
    public let membershipRank: Rank?
    public let displayId: String?
    
    public init(
        id: String,
        name: String,
        email: String,
        gender: Gender,
        birthYear: Int?,
        joinedAt: Date?,
        iconURL: String?,
        membershipRank: Rank?,
        displayId: String?
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.gender = gender
        self.birthYear = birthYear
        self.joinedAt = joinedAt
        self.iconURL = iconURL
        self.membershipRank = membershipRank
        self.displayId = displayId
    }
    
    // MARK: - 性別
    public enum Gender: String, CaseIterable, Hashable {
        case male, female, unknown
        
        public var label: String {
            switch self {
            case .male: return "男性"
            case .female: return "女性"
            case .unknown: return "不明"
            }
        }
    }
    
    // MARK: - 会員ランク（5段階）
    public enum Rank: String, CaseIterable, Hashable {
        case regular = "Regular"
        case bronze  = "Bronze"
        case silver  = "Silver"
        case gold    = "Gold"
        case platinum = "Platinum"
        
        public var label: String {
            switch self {
            case .regular:  return "レギュラー"
            case .bronze:   return "ブロンズ"
            case .silver:   return "シルバー"
            case .gold:     return "ゴールド"
            case .platinum: return "プラチナ"
            }
        }
    }
    
    public var age: Int? {
        guard let year = birthYear else { return nil }
        let currentYear = Calendar.current.component(.year, from: Date())
        return currentYear - year
    }
}

// MARK: - Firestore → UserItem 変換
public extension UserItem {
    static func from(document: DocumentSnapshot) -> UserItem? {
        guard let data = document.data() else { return nil }
        
        let name = data["name"] as? String ?? "(無名)"
        let email = data["email"] as? String ?? ""
        
        let genderStr = (data["gender"] as? String ?? "").lowercased()
        let gender = Gender(rawValue: genderStr) ?? .unknown
        
        let birthYear = data["birthYear"] as? Int
        
        var joinedDate: Date? = nil
        if let ts = data["joinedAt"] as? Timestamp {
            joinedDate = ts.dateValue()
        } else if let str = data["joinedAt"] as? String {
            joinedDate = ISO8601DateFormatter().date(from: str)
        }
        
        let iconURL = data["iconURL"] as? String
        let displayId = data["displayId"] as? String
        
        // 既存 Bronze/Silver/Gold に加え Regular/Platinum 対応
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
