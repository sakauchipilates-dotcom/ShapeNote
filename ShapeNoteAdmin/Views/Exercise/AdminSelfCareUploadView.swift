import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage
import UIKit

struct SelfCareSheetItem: Identifiable {
    let id: String
    let title: String
    let imageURL: String
    let storagePath: String
    let createdAt: Date
}

struct AdminSelfCareUploadView: View {
    @State private var sheetTitle = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var selfCareItems: [SelfCareSheetItem] = []
    @State private var isUploading = false
    @State private var showStatus = false
    @State private var status = ""

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    @State private var listener: ListenerRegistration?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: 投稿フォーム
                VStack(alignment: .leading, spacing: 16) {
                    Label("セルフケアシートの追加", systemImage: "doc.text.fill")
                        .font(.headline)
                        .foregroundColor(.white)

                    TextField("シートのタイトル（例：肩こり改善セルフケア）", text: $sheetTitle)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 12) {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
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
                            if isUploading { ProgressView() }
                            Text(isUploading ? "アップロード中..." : "Storageへアップロードして登録")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isUploading ? Color.gray : Color.white)
                        .foregroundColor(.green)
                        .cornerRadius(10)
                    }
                    .disabled(isUploading || sheetTitle.trimmingCharacters(in: .whitespaces).isEmpty || pickedImage == nil)

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
                        colors: [
                            Color(.sRGB, red: 0.50, green: 0.60, blue: 0.55),
                            Color(.sRGB, red: 0.45, green: 0.55, blue: 0.50)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                .padding(.horizontal)
                .onChange(of: pickerItem) { _, newValue in
                    Task { await loadPickedImage(newValue) }
                }

                // MARK: 登録済み一覧
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
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("セルフケア投稿・管理")
        .onAppear(perform: startListening)
        .onDisappear { listener?.remove() }
    }
}

// MARK: - Firestore / Storage 処理
private extension AdminSelfCareUploadView {
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
        let scale = min(1.0, maxDim / max(size.width, size.height))
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
        return (data, Int(newSize.width), Int(newSize.height))
    }

    func uploadSelfCareSheet() {
        guard let img = pickedImage else {
            show("❌ 画像を選択してください。", error: true); return
        }
        guard let pack = compressedJPEGData(from: img) else {
            show("❌ 画像の圧縮に失敗しました。", error: true); return
        }

        isUploading = true
        let id = UUID().uuidString
        let path = "admin_uploads/selfcare_sheets/\(id).jpg"
        let ref = storage.reference(withPath: path)
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"

        ref.putData(pack.data, metadata: meta) { _, error in
            if let error = error {
                isUploading = false
                show("❌ Storageアップロード失敗: \(error.localizedDescription)", error: true)
                return
            }
            ref.downloadURL { url, err in
                if let err = err {
                    isUploading = false
                    show("❌ URL取得失敗: \(err.localizedDescription)", error: true)
                    return
                }
                guard let url else { return }
                let doc: [String: Any] = [
                    "title": sheetTitle.trimmingCharacters(in: .whitespaces),
                    "imageURL": url.absoluteString,
                    "storagePath": path,
                    "createdAt": Timestamp(date: Date())
                ]
                db.collection("exercises").document("selfCareSheets")
                    .collection("items").document(id)
                    .setData(doc) { e in
                        isUploading = false
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

    func startListening() {
        listener?.remove()
        listener = db.collection("exercises").document("selfCareSheets")
            .collection("items").order(by: "createdAt", descending: true)
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
        storage.reference(withPath: item.storagePath).delete { err in
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
