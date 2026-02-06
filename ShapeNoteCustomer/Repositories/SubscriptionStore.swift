import Foundation
import Combine
import StoreKit
import FirebaseAuth

/// StoreKit 2 を使ったサブスク購入処理
@MainActor
final class SubscriptionStore: ObservableObject {

    // 購入中フラグ
    @Published private(set) var isPurchasing: Bool = false
    @Published private(set) var lastErrorMessage: String? = nil

    // App Store Connect で作成した Product ID
    private let productId = "shapenote.premium.monthly"

    // Firestore 側のサブスク状態を扱う既存 Repo
    private let subscriptionRepo: SubscriptionRepository

    init(subscriptionRepo: SubscriptionRepository = FirestoreSubscriptionRepository()) {
        self.subscriptionRepo = subscriptionRepo
    }

    /// プレミアム（月額）の購入メイン処理
    func purchasePremium() async throws {
        guard let user = Auth.auth().currentUser else {
            throw StoreError.noCurrentUser
        }

        // 🧪 ここで実機ビルドの Bundle ID を確認
        let bundleId = Bundle.main.bundleIdentifier ?? "nil"
        print("📦 bundleIdentifier at runtime = \(bundleId)")

        isPurchasing = true
        lastErrorMessage = nil
        defer { isPurchasing = false }

        do {
            // ① 対象のプロダクト取得
            let products = try await Product.products(for: [productId])

            // 🧪 StoreKit デバッグログ
            print("🧪 StoreKit debug ------------")
            print("🧪 requested productId = \(productId)")
            print("🧪 products.count = \(products.count)")
            for p in products {
                print("🧪 product.id = \(p.id)")
                print("🧪 displayName = \(p.displayName)")
                if let sub = p.subscription {
                    print("🧪 subscription info exists: \(sub)")
                    print("🧪 subscription period: \(sub.subscriptionPeriod)")
                } else {
                    print("🧪 subscription info: nil")
                }
            }
            print("🧪 ---------------------------")

            guard let product = products.first else {
                throw StoreError.productNotFound
            }

            // ② 購入フロー開始
            let result = try await product.purchase()

            // ③ 購入結果のハンドリング
            let transaction = try await handlePurchaseResult(result)

            // ④ Firestore 側のサブスク状態を更新
            try await updateSubscription(for: user, with: transaction)

            // ⑤ トランザクションを完了
            await transaction.finish()

        } catch let storeError as StoreError {
            // 自前エラー
            lastErrorMessage = storeError.errorDescription
            print("❌ StoreError: \(storeError)")
            throw storeError

        } catch {
            // 想定外エラー
            lastErrorMessage = error.localizedDescription
            print("❌ Unexpected StoreKit error: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Purchase Result handling

    private func handlePurchaseResult(
        _ result: Product.PurchaseResult
    ) async throws -> Transaction {
        switch result {
        case .success(let verificationResult):
            // App Store から返された署名付きトランザクションを検証
            print("🧾 Purchase result: success (verification pending)")
            return try checkVerified(verificationResult)

        case .userCancelled:
            print("🧾 Purchase result: userCancelled")
            throw StoreError.userCancelled

        case .pending:
            print("🧾 Purchase result: pending")
            throw StoreError.pending

        @unknown default:
            print("🧾 Purchase result: unknown default")
            throw StoreError.unknown
        }
    }

    /// App Store から返された署名付きトランザクションを検証
    private func checkVerified(
        _ result: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            print("✅ StoreKit verification success. transactionID=\(transaction.id)")
            return transaction

        case .unverified(_, let error):
            // 検証 NG。ログだけ残して共通エラーにする
            print("❌ StoreKit verification failed: \(error.localizedDescription)")
            throw StoreError.unverified
        }
    }

    // MARK: - Firestore 連携

    private func updateSubscription(
        for user: User,
        with transaction: Transaction
    ) async throws {

        let startDate = transaction.purchaseDate

        // 実際の有効期限取得ロジックは今後の拡張ポイントとし、
        // 現時点では「購入日から1か月後」を有効期限として扱う
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)

        let state = SubscriptionState(
            tier: .premium,
            startedAt: startDate,
            expiresAt: endDate,
            updatedAt: Date()
        )

        print("📡 Updating subscription in Firestore. uid=\(user.uid), expiresAt=\(endDate?.description ?? "nil")")
        try await subscriptionRepo.upsert(uid: user.uid, state: state)
    }

    // MARK: - エラー定義

    enum StoreError: LocalizedError {
        case noCurrentUser
        case productNotFound
        case userCancelled
        case pending
        case unverified
        case unknown

        var errorDescription: String? {
            switch self {
            case .noCurrentUser:
                return "ログイン情報を確認できませんでした。再度ログインしてからお試しください。"
            case .productNotFound:
                return "購入対象のプランが見つかりませんでした。時間をおいて再度お試しください。"
            case .userCancelled:
                return "購入処理をキャンセルしました。"
            case .pending:
                return "購入処理が保留中です。しばらくしてから再度ご確認ください。"
            case .unverified:
                return "購入情報の検証に失敗しました。決済が完了していない可能性があります。"
            case .unknown:
                return "予期しないエラーが発生しました。時間をおいて再度お試しください。"
            }
        }
    }
}
