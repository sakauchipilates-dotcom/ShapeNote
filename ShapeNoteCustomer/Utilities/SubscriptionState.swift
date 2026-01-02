import Foundation

enum SubscriptionTier: String, Codable {
    case free
    case premium
}

struct SubscriptionState: Codable, Equatable {
    var tier: SubscriptionTier = .free
    var updatedAt: Date? = nil

    var isPremium: Bool { tier == .premium }

    static let free = SubscriptionState(tier: .free, updatedAt: nil)
    static let premium = SubscriptionState(tier: .premium, updatedAt: nil)
}
