import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore

struct AdminExerciseExplainUploadView: View {
    @State private var explainTitle = ""
    @State private var explainDescription = ""
    @State private var pickedImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var statusMessage = ""
    @State private var showStatus = false
    @State private var explainItems: [ExerciseExplainSheetItem] = []

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // MARK: - 新規登録フォーム
                VStack(alignment: .leading, spacing: 16) {
                    Label("エクササイズ解説シートを追加", systemImage: "figure.mind.and.body")
                        .font(.headline)
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 12) {
                        TextField("タイトル（例：スクワットフォーム解説）", text: $explainTitle)
                            .textFieldStyle(.roundedBorder)

                        TextField("解説文（例：膝がつま先より前に出ないよう注意）", text: $explainDescription, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3, reservesSpace: true)

                        HStack(spacing: 12) {
                            PhotosPicker(selection: $pickerItem, matching: .images) {
                                Label(pickedImage == nil ? "画像を選択" : "画像を変更", systemImage: "photo")
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
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                            }
                        }

                        Button(action: uploadExplainSheet) {
                            HStack {
                                if isUploading { ProgressView() }
                                Text(isUploading ? "アップロード中..." : "登録する")
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isUploading ? Color.gray : Color.white)
                            .foregroundColor(.green)
                            .cornerRadius(10)
                        }
                        .disabled(isUploading || explainTitle.isEmpty || explainDescription.isEmpty || pickedImage == nil)

                        if showStatus {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundColor(statusMessage.contains("✅") ? .green : .red)
                                .transition(.opacity)
                        }
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.25, green: 0.50, blue: 0.70),
                                 Color(red: 0.15, green: 0.40, blue: 0.60)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                .padding(.horizontal)
                .onChange(of: pickerItem) { _, newValue in
                    Task { await loadPickedImage(newValue) }
                }

                // MARK: - 登録済み一覧
                VStack(alignment: .leading, spacing: 12) {
                    Label("登録済みエクササイズ解説シート", systemImage: "list.bullet.rectangle")
                        .font(.headline)

                    if explainItems.isEmpty {
                        Text("まだ登録がありません。")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        ForEach(explainItems) { item in
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: item.imageURL)) { phase in
                                    switch phase {
                                    case .success(let img): img.resizable().scaledToFill()
                                    case .failure: Color.red.opacity(0.2)
                                    default: Color.gray.opacity(0.2)
                                    }
                                }
                                .frame(width: 90, height: 60)
                                .clipped()
                                .cornerRadius(8)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.subheadline.bold())
                                    Text(item.description)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    deleteExplainSheet(item)
                                } label: {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.red)
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
            .padding(.vertical, 16)
        }
        .navigationTitle("エクササイズ解説シート")
        .navigationBarTitleDisplayMode(.inline)
        .task { await fetchExplainSheets() }
    }

    // MARK: - Firestore操作
    private func uploadExplainSheet() {
        guard let imageData = pickedImage?.jpegData(compressionQuality: 0.6) else { return }
        let id = UUID().uuidString
        let storagePath = "admin_uploads/explain_sheets/\(id).jpg"
        let ref = storage.reference().child(storagePath)

        isUploading = true
        statusMessage = "アップロード中..."
        showStatus = true

        ref.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                updateStatus("❌ アップロード失敗: \(error.localizedDescription)")
                return
            }
            ref.downloadURL { url, _ in
                guard let url = url else {
                    updateStatus("❌ URL取得失敗")
                    return
                }
                let data: [String: Any] = [
                    "title": explainTitle,
                    "description": explainDescription,
                    "imageURL": url.absoluteString,
                    "storagePath": storagePath,
                    "createdAt": Timestamp()
                ]
                db.collection("exercise_explain_sheets").document(id).setData(data) { error in
                    if let error = error {
                        updateStatus("❌ Firestore保存失敗: \(error.localizedDescription)")
                    } else {
                        updateStatus("✅ 登録完了！")
                        explainTitle = ""
                        explainDescription = ""
                        pickedImage = nil
                        Task { await fetchExplainSheets() }
                    }
                }
            }
        }
    }

    private func fetchExplainSheets() async {
        do {
            let snapshot = try await db.collection("exercise_explain_sheets")
                .order(by: "createdAt", descending: true)
                .getDocuments()
            let items = snapshot.documents.compactMap { doc -> ExerciseExplainSheetItem? in
                let d = doc.data()
                return ExerciseExplainSheetItem(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    description: d["description"] as? String ?? "",
                    imageURL: d["imageURL"] as? String ?? "",
                    storagePath: d["storagePath"] as? String ?? "",
                    createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
            await MainActor.run { self.explainItems = items }
        } catch {
            print("❌ Fetch Error: \(error.localizedDescription)")
        }
    }

    private func deleteExplainSheet(_ item: ExerciseExplainSheetItem) {
        db.collection("exercise_explain_sheets").document(item.id).delete()
        storage.reference().child(item.storagePath).delete { _ in
            Task { await fetchExplainSheets() }
        }
    }

    private func updateStatus(_ message: String) {
        DispatchQueue.main.async {
            self.statusMessage = message
            self.isUploading = false
            withAnimation { self.showStatus = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { self.showStatus = false }
            }
        }
    }

    private func loadPickedImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            await MainActor.run { self.pickedImage = uiImage }
        }
    }
}

// MARK: - モデル
struct ExerciseExplainSheetItem: Identifiable {
    let id: String
    let title: String
    let description: String
    let imageURL: String
    let storagePath: String
    let createdAt: Date
}

#Preview {
    AdminExerciseExplainUploadView()
}
