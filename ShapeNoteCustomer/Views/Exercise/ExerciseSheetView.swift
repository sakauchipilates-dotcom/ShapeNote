import SwiftUI

struct ExerciseSheetView: View {

    @EnvironmentObject private var appState: CustomerAppState

    @StateObject private var viewModel = ExerciseViewModel()
    @State private var isSheetExpanded = true
    @State private var isVideoExpanded = true
    @State private var isImageExpanded = true

    @State private var showGateAlert: Bool = false
    @State private var gateMessage: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ✅ 無料：YouTubeのみ
                    if appState.subscriptionState.isPremium {
                        // セルフケアシート（Premium）
                        CollapsibleSectionView(
                            title: "セルフケアシート",
                            description: "管理者から送られたセルフケア用の資料です。",
                            items: viewModel.selfCareSheets.map { sheet in
                                ExerciseItemViewData(
                                    title: sheet.title,
                                    action: {
                                        if !viewModel.openSheet(sheet, isPremium: true) {
                                            gateMessage = viewModel.gateMessage ?? "この機能はプレミアム限定です。"
                                            showGateAlert = true
                                        }
                                    }
                                )
                            },
                            icon: "doc.text",
                            isExpanded: $isSheetExpanded
                        )
                    } else {
                        lockedCard(
                            title: "セルフケアシート",
                            description: "プレミアム会員で閲覧できます。",
                            systemImage: "doc.text"
                        )
                    }

                    // おすすめ動画（Free/Premium共通）
                    CollapsibleYouTubeSectionView(
                        title: "おすすめ動画",
                        description: "あなたにおすすめのエクササイズ動画。",
                        videos: viewModel.youtubeLinks,
                        icon: "play.rectangle.fill",
                        isExpanded: $isVideoExpanded,
                        onTap: viewModel.openYouTube
                    )

                    if appState.subscriptionState.isPremium {
                        // エクササイズ解説シート（Premium）
                        CollapsibleSectionView(
                            title: "エクササイズ解説シート",
                            description: "動作やフォーム確認用の画像資料です。",
                            items: viewModel.exerciseImages.map { image in
                                ExerciseItemViewData(
                                    title: image.title,
                                    action: {
                                        let sheet = ExerciseSheet(title: image.title, url: image.url)
                                        if !viewModel.openSheet(sheet, isPremium: true) {
                                            gateMessage = viewModel.gateMessage ?? "この機能はプレミアム限定です。"
                                            showGateAlert = true
                                        }
                                    }
                                )
                            },
                            icon: "figure.mind.and.body",
                            isExpanded: $isImageExpanded
                        )
                    } else {
                        lockedCard(
                            title: "エクササイズ解説シート",
                            description: "プレミアム会員で閲覧できます。",
                            systemImage: "figure.mind.and.body"
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("エクササイズ")
            .background(Color(.systemGroupedBackground))
            .alert("プレミアム限定", isPresented: $showGateAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(gateMessage)
            }
        }
    }

    private func lockedCard(title: String, description: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
            }

            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("月額440円で解放")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}
