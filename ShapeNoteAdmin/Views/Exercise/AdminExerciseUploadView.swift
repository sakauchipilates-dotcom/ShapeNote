import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage
import UIKit

// MARK: - Firestore モデル
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

struct SelfCareSheetItem: Identifiable {
    let id: String
    let title: String
    let imageURL: String
    let storagePath: String
    let createdAt: Date
}

enum AdminExerciseSection: String, CaseIterable {
    case selfCare = "セルフケアシート"
    case youtube  = "おすすめ動画"
}

// MARK: - メインビュー
struct AdminExerciseUploadView: View {
    // MARK: - セクション切替
    @State private var current: AdminExerciseSection = .selfCare
    
    // MARK: - SelfCare（画像）投稿
    @State private var sheetTitle: String = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var selfCareItems: [SelfCareSheetItem] = []
    @State private var isUploadingSheet = false
    private let storage = Storage.storage()
    
    // MARK: - YouTube 投稿
    @State private var ytTitle: String = ""
    @State private var ytURL: String = ""
    @State private var ytChannel: String = ""
    @State private var videos: [YouTubeVideoItem] = []
    @State private var ytUploading = false
    
    // 共通
    @State private var status: String = ""
    @State private var showStatus = false
    @State private var selfcareListener: ListenerRegistration?
    @State private var youtubeListener: ListenerRegistration?
    private let db = Firestore.firestore()
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // セグメント切替
                Picker("", selection: $current) {
                    ForEach(AdminExerciseSection.allCases, id: \.self) { sec in
                        Text(sec.rawValue).tag(sec)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // セクション本体
                if current == .selfCare {
                    selfCareSection
                } else {
                    youtubeSection
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("エクササイズ投稿・管理")
        .background(Color(.systemGroupedBackground))
        .onAppear {
            startSelfCareListening()
            startYoutubeListening()
        }
        .onDisappear {
            selfcareListener?.remove()
            youtubeListener?.remove()
        }
    }
}

// MARK: - セルフケアシートセクション
private extension AdminExerciseUploadView {
    var selfCareSection: some View {
        Group {
            // フォーム部分
            VStack(alignment: .leading, spacing: 16) {
                Label("セルフケアシートの追加", systemImage: "doc.text.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 12) {
                    TextField("シートのタイトル（例：肩こり改善セルフケア）", text: $sheetTitle)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $pickerItem, matching: .images, preferredItemEncoding: .automatic) {
                            Label(pickedImage == nil ? "画像を選択" : "画像を変更", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(Color.white)
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                        }
                        
                        if let image = pickedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipped()
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
                        }
                    }
                    
                    Button(action: uploadSelfCareSheet) {
                        HStack {
                            if isUploadingSheet { ProgressView() }
                            Text(isUploadingSheet ? "アップロード中..." : "Storageへアップロードして登録")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isUploadingSheet ? Color.gray : Color.white)
                        .foregroundColor(.green)
                        .cornerRadius(10)
                    }
                    .disabled(isUploadingSheet || sheetTitle.trimmingCharacters(in: .whitespaces).isEmpty || pickedImage == nil)
                    
                    if showStatus {
                        Text(status)
                            .font(.footnote)
                            .foregroundColor(status.contains("✅") ? .green : .white)
                            .transition(.opacity)
                    }
                }
                .onChange(of: pickerItem) { _, newValue in
                    Task { await loadPickedImage(newValue) }
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        Color(.sRGB, red: 0.50, green: 0.60, blue: 0.55, opacity: 1.0),
                        Color(.sRGB, red: 0.45, green: 0.55, blue: 0.50, opacity: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
            .padding(.horizontal)
            
            // 一覧部分
            VStack(alignment: .leading, spacing: 12) {
                Label("登録済みセルフケアシート", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                
                if selfCareItems.isEmpty {
                    Text("まだ登録がありません。")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 30)
                } else {
                    ForEach(selfCareItems) { item in
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: item.imageURL)) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFill()
                                case .empty: Color.gray.opacity(0.15)
                                case .failure: Color.red.opacity(0.15)
                                @unknown default: Color.gray.opacity(0.15)
                                }
                            }
                            .frame(width: 90, height: 62)
                            .clipped()
                            .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.subheadline.bold())
                                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                deleteSelfCare(item)
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
    }
    
    // MARK: - 画像関連処理
    func loadPickedImage(_ item: PhotosPickerItem?) async {
        guard let item else { pickedImage = nil; return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                pickedImage = img
            }
        } catch {
            show("❌ 画像の読み込みに失敗しました: \(error.localizedDescription)", error: true)
        }
    }
    
    func compressedJPEGData(from image: UIImage) -> (data: Data, width: Int, height: Int)? {
        let maxDim: CGFloat = 1600
        let size = image.size
        var scale: CGFloat = 1.0
        if max(size.width, size.height) > maxDim {
            scale = maxDim / max(size.width, size.height)
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        
        var quality: CGFloat = 0.82
        var data = resized.jpegData(compressionQuality: quality) ?? Data()
        while data.count > 800 * 1024 && quality > 0.55 {
            quality -= 0.07
            data = resized.jpegData(compressionQuality: quality) ?? data
        }
        guard !data.isEmpty else { return nil }
        return (data, Int(newSize.width.rounded()), Int(newSize.height.rounded()))
    }
    
    func uploadSelfCareSheet() {
        guard let img = pickedImage else {
            show("❌ 画像を選択してください。", error: true); return
        }
        guard let pack = compressedJPEGData(from: img) else {
            show("❌ 画像の圧縮に失敗しました。", error: true); return
        }
        isUploadingSheet = true
        let id = UUID().uuidString
        let path = "admin_uploads/selfcare_sheets/\(id).jpg"
        let ref = storage.reference(withPath: path)
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        
        ref.putData(pack.data, metadata: meta) { _, error in
            if let error = error {
                isUploadingSheet = false
                show("❌ Storageアップロード失敗: \(error.localizedDescription)", error: true)
                return
            }
            ref.downloadURL { url, err in
                if let err = err {
                    isUploadingSheet = false
                    show("❌ URL取得失敗: \(err.localizedDescription)", error: true)
                    return
                }
                guard let url else { return }
                let doc: [String: Any] = [
                    "title": sheetTitle.trimmingCharacters(in: .whitespaces),
                    "imageURL": url.absoluteString,
                    "storagePath": path,
                    "width": pack.width,
                    "height": pack.height,
                    "sizeBytes": pack.data.count,
                    "createdAt": Timestamp(date: Date())
                ]
                db.collection("exercises").document("selfCareSheets")
                    .collection("items").document(id)
                    .setData(doc) { e in
                        isUploadingSheet = false
                        if let e = e {
                            show("❌ Firestore登録失敗: \(e.localizedDescription)", error: true)
                        } else {
                            show("✅ セルフケアシートを登録しました。", error: false)
                            Haptics.success()
                            sheetTitle = ""
                            pickedImage = nil
                        }
                    }
            }
        }
    }
    
    func startSelfCareListening() {
        selfcareListener?.remove()
        selfcareListener = db.collection("exercises").document("selfCareSheets")
            .collection("items")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snap, err in
                if let err = err {
                    print("❌ selfCare listener: \(err.localizedDescription)")
                    return
                }
                guard let docs = snap?.documents else { return }
                selfCareItems = docs.compactMap { d in
                    let data = d.data()
                    return SelfCareSheetItem(
                        id: d.documentID,
                        title: data["title"] as? String ?? "無題",
                        imageURL: data["imageURL"] as? String ?? "",
                        storagePath: data["storagePath"] as? String ?? "",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            }
    }
    
    func deleteSelfCare(_ item: SelfCareSheetItem) {
        let ref = storage.reference(withPath: item.storagePath)
        ref.delete { err in
            if let err = err {
                show("❌ Storage削除失敗: \(err.localizedDescription)", error: true)
                return
            }
            db.collection("exercises").document("selfCareSheets")
                .collection("items").document(item.id).delete { e in
                    if let e = e {
                        show("❌ Firestore削除失敗: \(e.localizedDescription)", error: true)
                    } else {
                        show("🗑 削除しました：\(item.title)", error: false)
                    }
                }
        }
    }
}

// MARK: - おすすめ動画セクション
private extension AdminExerciseUploadView {
    var youtubeSection: some View {
        Group {
            VStack(alignment: .leading, spacing: 16) {
                Label("YouTubeおすすめ動画の投稿", systemImage: "play.rectangle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Group {
                    TextField("動画タイトル（例：体幹を鍛える呼吸法）", text: $ytTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("YouTube URL（https://〜）", text: $ytURL)
                        .keyboardType(.URL)
                        .textFieldStyle(.roundedBorder)
                    TextField("チャンネル名（例：PT Body Lab Channel）", text: $ytChannel)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button(action: uploadVideo) {
                    HStack {
                        if ytUploading { ProgressView() }
                        Text(ytUploading ? "アップロード中..." : "Firestoreへ登録する")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ytUploading ? Color.gray : Color.white)
                    .foregroundColor(.red)
                    .cornerRadius(10)
                }
                .disabled(ytUploading || ytTitle.isEmpty || ytURL.isEmpty)
                
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
    }
    
    func uploadVideo() {
        guard !ytTitle.isEmpty, !ytURL.isEmpty else {
            show("❌ タイトルとURLを入力してください。", error: true); return
        }
        guard ytURL.starts(with: "https://") else {
            show("⚠️ URLは「https://」から始めてください。", error: true); return
        }
        ytUploading = true
        let newVideo: [String: Any] = [
            "title": ytTitle,
            "url": ytURL,
            "channel": ytChannel.isEmpty ? "未設定" : ytChannel,
            "createdAt": Timestamp(date: Date())
        ]
        db.collection("exercises").document("youtubeVideos")
            .collection("items")
            .addDocument(data: newVideo) { err in
                ytUploading = false
                if let err = err {
                    show("❌ Firestore登録失敗: \(err.localizedDescription)", error: true)
                } else {
                    show("✅ Firestoreに登録成功！", error: false)
                    Haptics.success()
                    ytTitle = ""; ytURL = ""; ytChannel = ""
                }
            }
    }
    
    func startYoutubeListening() {
        youtubeListener?.remove()
        youtubeListener = db.collection("exercises").document("youtubeVideos")
            .collection("items")
            .order(by: "createdAt", descending: true)
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
}

// MARK: - 共通ヘルパー
private extension AdminExerciseUploadView {
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
