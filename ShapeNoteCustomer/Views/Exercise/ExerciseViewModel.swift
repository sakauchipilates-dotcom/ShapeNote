import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import UIKit

@MainActor
final class ExerciseViewModel: ObservableObject {
    @Published var message: String = "データ読み込み前"
    @Published var selfCareSheets: [ExerciseSheet] = []
    @Published var exerciseImages: [ExerciseImage] = []
    @Published var youtubeLinks: [YouTubeVideo] = []
    
    private var listener: ListenerRegistration?
    
    init() {
        Task {
            await loadInitialData()
            startListeningForYouTubeVideos()
        }
    }
    
    deinit {
        listener?.remove()
    }

    // MARK: - Firestore 初期データ読み込み
    func loadInitialData() async {
        do {
            let db = Firestore.firestore()
            let uid = Auth.auth().currentUser?.uid ?? "guest"
            let doc = try await db.collection("users").document(uid).getDocument()
            
            if let data = doc.data() {
                self.message = "データ取得完了: \(data.count)項目"
            } else {
                self.message = "データなし"
            }
            
            loadSampleData()
        } catch {
            print("❌ Firestore読み込みエラー: \(error)")
            self.message = "取得失敗: \(error.localizedDescription)"
            loadSampleData()
        }
    }
    
    // MARK: - Firestore リアルタイム監視（YouTubeおすすめ動画）
    func startListeningForYouTubeVideos() {
        let db = Firestore.firestore()
        listener = db.collection("exercises")
            .document("youtubeVideos")
            .collection("items")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Firestore Listener Error: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No YouTube video data found.")
                    return
                }
                
                // Firestore → モデル変換
                let videos: [YouTubeVideo] = documents.compactMap { doc in
                    let data = doc.data()
                    guard
                        let title = data["title"] as? String,
                        let url = data["url"] as? String
                    else { return nil }
                    
                    let channel = data["channel"] as? String ?? "未設定"
                    return YouTubeVideo(title: title, url: url, channel: channel)
                }
                
                DispatchQueue.main.async {
                    self.youtubeLinks = videos
                    self.message = "おすすめ動画を更新しました（\(videos.count)件）"
                }
            }
    }

    // MARK: - 動画・シートの開く処理
    func openSheet(_ sheet: ExerciseSheet) {
        if let url = URL(string: sheet.url) {
            UIApplication.shared.open(url)
        }
    }

    func openYouTube(_ video: YouTubeVideo) {
        if let url = URL(string: video.url) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - ダミーデータ（バックアップ）
    private func loadSampleData() {
        self.selfCareSheets = [
            ExerciseSheet(title: "肩こり改善セルフケア", url: "https://example.com/sheet1.pdf"),
            ExerciseSheet(title: "腰痛予防ストレッチ", url: "https://example.com/sheet2.pdf")
        ]

        self.exerciseImages = [
            ExerciseImage(title: "胸のストレッチ", url: "https://picsum.photos/200/200?1"),
            ExerciseImage(title: "股関節モビリティ", url: "https://picsum.photos/200/200?2"),
            ExerciseImage(title: "背骨のローリング", url: "https://picsum.photos/200/200?3")
        ]

        // 初期は空にしておく（Firestore Listenerで自動更新される）
        self.youtubeLinks = []
    }
}

// MARK: - モデル定義
struct ExerciseSheet: Identifiable, Codable {
    let id = UUID()
    let title: String
    let url: String
}

struct ExerciseImage: Identifiable, Codable {
    let id = UUID()
    let title: String
    let url: String
}

struct YouTubeVideo: Identifiable, Codable {
    let id = UUID()
    let title: String
    let url: String
    let channel: String
    
    var thumbnailURL: String {
        // YouTube URLから動画IDを抽出
        if let range = url.range(of: "youtu.be/") {
            let videoId = String(url[range.upperBound...])
            return "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg"
        } else if let range = url.range(of: "v=") {
            let videoId = String(url[range.upperBound...]).components(separatedBy: "&").first ?? ""
            return "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg"
        } else {
            return "https://img.youtube.com/vi/default/hqdefault.jpg"
        }
    }
}
