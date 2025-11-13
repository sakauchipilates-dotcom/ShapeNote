import SwiftUI
import FirebaseFirestore
import UIKit

struct YouTubeVideoItem: Identifiable {
    let id: String
    let title: String
    let url: String
    let channel: String

    var thumbnailURL: String {
        if let r = url.range(of: "youtu.be/") {
            let id = String(url[r.upperBound...])
            return "https://img.youtube.com/vi/\(id)/hqdefault.jpg"
        } else if let r = url.range(of: "v=") {
            let id = String(url[r.upperBound...]).components(separatedBy: "&").first ?? ""
            return "https://img.youtube.com/vi/\(id)/hqdefault.jpg"
        }
        return "https://img.youtube.com/vi/default/hqdefault.jpg"
    }
}

struct AdminYouTubeUploadView: View {
    @State private var ytTitle = ""
    @State private var ytURL = ""
    @State private var ytChannel = ""
    @State private var videos: [YouTubeVideoItem] = []
    @State private var isUploading = false
    @State private var showStatus = false
    @State private var status = ""

    private let db = Firestore.firestore()
    @State private var listener: ListenerRegistration?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: 投稿フォーム
                VStack(alignment: .leading, spacing: 16) {
                    Label("YouTubeおすすめ動画の投稿", systemImage: "play.rectangle.fill")
                        .font(.headline)
                        .foregroundColor(.white)

                    TextField("動画タイトル（例：体幹を鍛える呼吸法）", text: $ytTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("YouTube URL（https://〜）", text: $ytURL)
                        .keyboardType(.URL)
                        .textFieldStyle(.roundedBorder)
                    TextField("チャンネル名（例：PT Body Lab Channel）", text: $ytChannel)
                        .textFieldStyle(.roundedBorder)

                    Button(action: uploadVideo) {
                        HStack {
                            if isUploading { ProgressView() }
                            Text(isUploading ? "アップロード中..." : "Firestoreへ登録する")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isUploading ? Color.gray : Color.white)
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }
                    .disabled(isUploading || ytTitle.isEmpty || ytURL.isEmpty)

                    if showStatus {
                        Text(status)
                            .font(.footnote)
                            .foregroundColor(status.contains("✅") ? .green : .white)
                            .transition(.opacity)
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.35, blue: 0.35),
                            Color(red: 0.85, green: 0.0, blue: 0.1)
                        ]),
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(20)
                .shadow(color: .red.opacity(0.25), radius: 6, x: 0, y: 2)
                .padding(.horizontal)

                // MARK: 登録済み一覧
                VStack(alignment: .leading, spacing: 16) {
                    Label("投稿済みおすすめ動画一覧", systemImage: "list.bullet")
                        .font(.headline)

                    if videos.isEmpty {
                        Text("まだ投稿がありません。")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 30)
                    } else {
                        ForEach(videos) { v in
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: v.thumbnailURL)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.2)
                                }
                                .frame(width: 90, height: 55)
                                .clipped()
                                .cornerRadius(8)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(v.title).font(.subheadline.bold())
                                    Text(v.channel).font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    deleteVideo(v)
                                } label: {
                                    Image(systemName: "trash.fill").foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(20)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("YouTube動画管理")
        .onAppear(perform: startListening)
        .onDisappear { listener?.remove() }
    }
}

// MARK: - Firestore処理
private extension AdminYouTubeUploadView {
    func uploadVideo() {
        guard !ytTitle.isEmpty, !ytURL.isEmpty else {
            show("❌ タイトルとURLを入力してください。", error: true); return
        }
        guard ytURL.starts(with: "https://") else {
            show("⚠️ URLは「https://」から始めてください。", error: true); return
        }

        isUploading = true
        let newVideo: [String: Any] = [
            "title": ytTitle,
            "url": ytURL,
            "channel": ytChannel.isEmpty ? "未設定" : ytChannel,
            "createdAt": Timestamp(date: Date())
        ]

        db.collection("exercises").document("youtubeVideos")
            .collection("items")
            .addDocument(data: newVideo) { err in
                isUploading = false
                if let err = err {
                    show("❌ Firestore登録失敗: \(err.localizedDescription)", error: true)
                } else {
                    show("✅ Firestoreに登録成功！", error: false)
                    Haptics.success()
                    ytTitle = ""; ytURL = ""; ytChannel = ""
                }
            }
    }

    func startListening() {
        listener?.remove()
        listener = db.collection("exercises").document("youtubeVideos")
            .collection("items").order(by: "createdAt", descending: true)
            .addSnapshotListener { snap, err in
                if let err = err {
                    print("❌ youtube listener: \(err.localizedDescription)")
                    return
                }
                guard let docs = snap?.documents else { return }
                videos = docs.compactMap { d in
                    let data = d.data()
                    return YouTubeVideoItem(
                        id: d.documentID,
                        title: data["title"] as? String ?? "不明なタイトル",
                        url: data["url"] as? String ?? "",
                        channel: data["channel"] as? String ?? "未設定"
                    )
                }
            }
    }

    func deleteVideo(_ video: YouTubeVideoItem) {
        db.collection("exercises").document("youtubeVideos")
            .collection("items").document(video.id)
            .delete { err in
                if let err = err {
                    show("❌ 削除失敗: \(err.localizedDescription)", error: true)
                } else {
                    show("🗑 削除完了: \(video.title)", error: false)
                }
            }
    }

    func show(_ message: String, error: Bool) {
        status = message
        withAnimation { showStatus = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showStatus = false }
        }
        if error { Haptics.error() }
    }
}

private enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
