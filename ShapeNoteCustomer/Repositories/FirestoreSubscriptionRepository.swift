import Foundation
import FirebaseFirestore

final class FirestoreSubscriptionRepository: SubscriptionRepository {

    private let db = Firestore.firestore()

    func fetch(uid: String) async throws -> SubscriptionState {
        let snap = try await db.collection("users").document(uid).getDocument()
        let data = snap.data() ?? [:]
        return Self.decodeSubscription(from: data).normalized()
    }

    func listen(
        uid: String,
        onChange: @escaping (Result<SubscriptionState, Error>) -> Void
    ) -> ListenerRegistration {
        db.collection("users").document(uid).addSnapshotListener { snap, err in
            if let err {
                onChange(.failure(err))
                return
            }
            let data = snap?.data() ?? [:]
            let state = Self.decodeSubscription(from: data).normalized()
            onChange(.success(state))
        }
    }

    func upsert(uid: String, state: SubscriptionState) async throws {
        var payload: [String: Any] = [
            "tier": state.tier.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let startedAt = state.startedAt {
            payload["startedAt"] = Timestamp(date: startedAt)
        }

        if let expiresAt = state.expiresAt {
            payload["expiresAt"] = Timestamp(date: expiresAt)
        } else {
            payload["expiresAt"] = FieldValue.delete()
        }

        try await db.collection("users").document(uid).setData([
            "subscription": payload
        ], merge: true)
    }

    private static func decodeSubscription(from userData: [String: Any]) -> SubscriptionState {
        let sub = userData["subscription"] as? [String: Any] ?? [:]

        let tierRaw = sub["tier"] as? String ?? SubscriptionTier.free.rawValue
        let tier = SubscriptionTier(rawValue: tierRaw) ?? .free

        let startedAt = (sub["startedAt"] as? Timestamp)?.dateValue()
        let expiresAt = (sub["expiresAt"] as? Timestamp)?.dateValue()
        let updatedAt = (sub["updatedAt"] as? Timestamp)?.dateValue()

        return SubscriptionState(
            tier: tier,
            startedAt: startedAt,
            expiresAt: expiresAt,
            updatedAt: updatedAt
        )
    }
}
