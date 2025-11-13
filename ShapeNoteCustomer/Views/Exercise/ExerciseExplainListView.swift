import SwiftUI
import FirebaseFirestore
import ShapeCore

// Firestore から読み込むモデル
struct ExerciseExplainItem: Identifiable {
    var id: String
    var title: String
    var description: String
    var imageUrl: String
    var createdAt: Date
}

struct ExerciseExplainListView: View {
    @State private var items: [ExerciseExplainItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let db = Firestore.firestore()

    var body: some View {
        ZStack {
            Theme.main.ignoresSafeArea()

            if isLoading {
                ProgressView("読み込み中…")
                    .tint(Theme.sub)
            } else if let error = errorMessage {
                Text("⚠️ \(error)")
                    .foregroundColor(.red)
                    .padding()
            } else if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.mind.and.body")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.6))
                    Text("まだ解説シートが登録されていません。")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(items) { item in
                            NavigationLink(destination: ExerciseExplainDetailView(item: item)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    AsyncImage(url: URL(string: item.imageUrl)) { phase in
                                        switch phase {
                                        case .success(let img):
                                            img.resizable()
                                                .scaledToFill()
                                                .frame(height: 150)
                                                .clipped()
                                                .cornerRadius(12)
                                        case .failure(_):
                                            Image(systemName: "photo")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(height: 120)
                                                .foregroundColor(.gray)
                                        default:
                                            ProgressView()
                                                .frame(height: 120)
                                        }
                                    }
                                    Text(item.title)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(item.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(14)
                                .shadow(color: Theme.shadow, radius: 4, x: 0, y: 2)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("エクササイズ解説シート")
        .navigationBarTitleDisplayMode(.inline)
        .task { await fetchItems() }
        .refreshable { await fetchItems() }
    }

    // Firestoreから取得
    private func fetchItems() async {
        do {
            let snapshot = try await db.collection("exercise_explain_sheets")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            let fetched = snapshot.documents.compactMap { doc -> ExerciseExplainItem? in
                let data = doc.data()
                return ExerciseExplainItem(
                    id: doc.documentID,
                    title: data["title"] as? String ?? "無題",
                    description: data["description"] as? String ?? "",
                    imageUrl: data["imageUrl"] as? String ?? "",
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }

            await MainActor.run {
                self.items = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

#Preview {
    NavigationStack { ExerciseExplainListView() }
}
