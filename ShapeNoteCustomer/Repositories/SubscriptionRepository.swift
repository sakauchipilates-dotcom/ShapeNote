import Foundation
import FirebaseFirestore

protocol SubscriptionRepository {
    func fetch(uid: String) async throws -> SubscriptionState

    func listen(
        uid: String,
        onChange: @escaping (Result<SubscriptionState, Error>) -> Void
    ) -> ListenerRegistration

    func upsert(uid: String, state: SubscriptionState) async throws
}

enum SubscriptionRepoError: Error {
    case noData
}
