import SwiftUI
import ShapeCore

struct ExerciseView: View {
    @StateObject private var viewModel = ExerciseViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: - セルフケアシート
                    sectionCard(
                        title: "セルフケアシート",
                        background: Theme.sub.opacity(0.08)
                    ) {
                        if viewModel.selfCareSheets.isEmpty {
                            Text("まだセルフケアシートがありません。")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else {
                            ForEach(viewModel.selfCareSheets, id: \.id) { sheet in
                                Button(action: { viewModel.openSheet(sheet) }) {
                                    HStack {
                                        Image(systemName: "doc.text.magnifyingglass")
                                            .foregroundColor(Theme.sub)
                                        Text(sheet.title)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(Theme.cardRadius)
                                    .shadow(color: Theme.shadow, radius: 3, x: 0, y: 1)
                                }
                            }
                        }
                    }

                    // MARK: - おすすめ動画
                    sectionCard(
                        title: "おすすめ動画",
                        background: Theme.accent.opacity(0.15)
                    ) {
                        if viewModel.youtubeLinks.isEmpty {
                            Text("おすすめ動画はまだありません。")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else {
                            ForEach(viewModel.youtubeLinks, id: \.id) { video in
                                Link(destination: URL(string: video.url)!) {
                                    HStack {
                                        Image(systemName: "play.rectangle.fill")
                                            .foregroundColor(.red.opacity(0.85))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(video.title)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text(video.channel)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(Theme.cardRadius)
                                    .shadow(color: Theme.shadow, radius: 3, x: 0, y: 1)
                                }
                            }
                        }
                    }

                    // MARK: - エクササイズ解説シート
                    sectionCard(
                        title: "エクササイズ解説シート",
                        background: Theme.sub.opacity(0.08)
                    ) {
                        if viewModel.exerciseImages.isEmpty {
                            Text("まだ解説シートがありません。")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(viewModel.exerciseImages, id: \.id) { image in
                                        // 🔽 ここでExerciseImage → ExerciseExplainItem に変換
                                        let explainItem = ExerciseExplainItem(
                                            id: image.id.uuidString,
                                            title: image.title,
                                            description: "",
                                            imageUrl: image.url,
                                            createdAt: Date()
                                        )

                                        NavigationLink(destination: ExerciseExplainDetailView(item: explainItem)) {
                                            VStack {
                                                AsyncImage(url: URL(string: image.url)) { phase in
                                                    switch phase {
                                                    case .success(let img):
                                                        img.resizable()
                                                            .scaledToFill()
                                                            .frame(width: 140, height: 140)
                                                            .clipped()
                                                            .cornerRadius(12)
                                                    case .failure(_):
                                                        Image(systemName: "exclamationmark.triangle")
                                                            .foregroundColor(.red)
                                                    default:
                                                        ProgressView()
                                                    }
                                                }
                                                Text(image.title)
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }

                            NavigationLink(destination: ExerciseExplainListView()) {
                                HStack {
                                    Spacer()
                                    Text("すべての解説シートを見る ▶︎")
                                        .font(.footnote)
                                        .foregroundColor(Theme.sub)
                                        .padding(.top, 8)
                                    Spacer()
                                }
                            }
                        }
                    }

                    // MARK: - 状態メッセージ
                    if !viewModel.message.isEmpty {
                        Text(viewModel.message)
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .background(Theme.main.ignoresSafeArea())
            .navigationTitle("エクササイズ")
        }
    }

    // MARK: - 共通セクションカード
    private func sectionCard<Content: View>(
        title: String,
        background: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(Theme.dark)
            content()
        }
        .padding()
        .background(background)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: Theme.shadow, radius: 3, x: 0, y: 2)
    }
}

#Preview {
    ExerciseView()
}
