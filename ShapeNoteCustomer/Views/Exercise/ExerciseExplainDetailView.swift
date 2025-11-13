import SwiftUI
import PhotosUI
import ShapeCore

struct ExerciseExplainDetailView: View {
    let item: ExerciseExplainItem
    @State private var showSaveAlert = false
    @State private var saveResultMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AsyncImage(url: URL(string: item.imageUrl)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .scaledToFit()
                            .cornerRadius(12)
                            .shadow(radius: 4)
                            .padding()
                            .onLongPressGesture { saveImageToPhotos() }
                    case .failure(_):
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .foregroundColor(.gray)
                            .padding()
                    default:
                        ProgressView()
                            .frame(height: 200)
                            .padding()
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(item.title)
                        .font(.title2.bold())
                        .foregroundColor(Theme.dark)

                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal)

                Button(action: saveImageToPhotos) {
                    Label("画像を保存する", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.sub)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 40)
        }
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.main.ignoresSafeArea())
        .alert("保存結果", isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveResultMessage)
        }
    }

    // MARK: - 画像保存処理
    private func saveImageToPhotos() {
        guard let url = URL(string: item.imageUrl),
              let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data) else {
            saveResultMessage = "❌ 画像を取得できませんでした。"
            showSaveAlert = true
            return
        }

        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
        saveResultMessage = "✅ カメラロールに保存しました。"
        showSaveAlert = true
    }
}

#Preview {
    ExerciseExplainDetailView(
        item: ExerciseExplainItem(
            id: "1",
            title: "肩こり改善ストレッチ",
            description: "肩甲骨を動かして血流を改善するストレッチです。",
            imageUrl: "https://example.com/sample.jpg",
            createdAt: Date()
        )
    )
}
