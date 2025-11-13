import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class StorageUsageVM: ObservableObject {
    // Storage
    @Published var totalGB: Double = 0
    @Published var imagesGB: Double = 0
    @Published var videosGB: Double = 0
    @Published var docsGB: Double = 0
    @Published var otherGB: Double = 0

    // Dashboard stats
    @Published var memberCount: Int = 0
    @Published var unreadCount: Int = 0
    @Published var sheetCount: Int = 0

    @Published var isLoading = false

    private let db = Firestore.firestore()

    // Firestore から /admin データを読み込む
    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let adminRef = db.collection("admins")

            // /admin/storageUsage
            let storageSnap = try await adminRef.document("storageUsage").getDocument()
            if let d = storageSnap.data() {
                totalGB  = d["totalGB"]  as? Double ?? 0
                imagesGB = d["imagesGB"] as? Double ?? 0
                videosGB = d["videosGB"] as? Double ?? 0
                docsGB   = d["docsGB"]   as? Double ?? 0
                otherGB  = d["otherGB"]  as? Double ?? 0
            }

            // /admin/dashboardStats
            let statsSnap = try await adminRef.document("dashboardStats").getDocument()
            if let s = statsSnap.data() {
                memberCount = s["memberCount"] as? Int ?? 0
                unreadCount = s["unreadCount"] as? Int ?? 0
                sheetCount  = s["sheetCount"]  as? Int ?? 0
            }
        } catch {
            print("⚠️ Firestore 読み込みエラー: \(error.localizedDescription)")
        }
    }

    // 計算プロパティ
    var usedTotalGB: Double {
        imagesGB + videosGB + docsGB + otherGB
    }
    var usagePercent: Double {
        guard totalGB > 0 else { return 0 }
        return (usedTotalGB / totalGB) * 100
    }
}
