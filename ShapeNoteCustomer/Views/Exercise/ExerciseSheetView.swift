import SwiftUI

struct ExerciseSheetView: View {
    @StateObject private var viewModel = ExerciseViewModel()
    @State private var isSheetExpanded = true
    @State private var isVideoExpanded = false
    @State private var isImageExpanded = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: - セルフケアシート
                    CollapsibleSectionView(
                        title: "セルフケアシート",
                        description: "管理者から送られたセルフケア用の資料です。",
                        items: viewModel.selfCareSheets.map { sheet in
                            ExerciseItemViewData(
                                title: sheet.title,
                                action: { viewModel.openSheet(sheet) }
                            )
                        },
                        icon: "doc.text",
                        isExpanded: $isSheetExpanded
                    )

                    // MARK: - おすすめ動画
                    CollapsibleYouTubeSectionView(
                        title: "おすすめ動画",
                        description: "あなたにおすすめのエクササイズ動画。",
                        videos: viewModel.youtubeLinks,
                        icon: "play.rectangle.fill",
                        isExpanded: $isVideoExpanded,
                        onTap: viewModel.openYouTube
                    )

                    // MARK: - エクササイズ解説シート（旧エクササイズ画像）
                    CollapsibleSectionView(
                        title: "エクササイズ解説シート",
                        description: "動作やフォーム確認用の画像資料です。",
                        items: viewModel.exerciseImages.map { image in
                            ExerciseItemViewData(
                                title: image.title,
                                action: { viewModel.openSheet(ExerciseSheet(title: image.title, url: image.url)) }
                            )
                        },
                        icon: "figure.mind.and.body",
                        isExpanded: $isImageExpanded
                    )
                }
                .padding()
            }
            .navigationTitle("エクササイズ")
            .background(Color(.systemGroupedBackground))
        }
    }
}
