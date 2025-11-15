import SwiftUI
import ShapeCore
import UIKit

struct PostureAnalysisFlowView: View {

    // Root（CustomerRootView）から渡される撮影画像
    let capturedImage: UIImage

    // NavigationStack 操作用のクロージャ
    let onPop: () -> Void          // カメラへ戻る
    let onPopToRoot: () -> Void    // Home（タブ0など）へ戻る

    @StateObject private var analyzer = PostureAnalyzer()
    @State private var state: AnalysisState = .loading
    @State private var started = false
    @State private var pipelineTask: Task<Void, Never>? = nil

    enum AnalysisState {
        case loading
        case success(result: PostureResult, skeleton: UIImage, report: UIImage)
        case failure(message: String)
    }

    var body: some View {
        switch state {

        // ------------------------------------------------------
        // MARK: - 解析中 UI
        // ------------------------------------------------------
        case .loading:
            ZStack {
                Theme.gradientMain
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    ProgressRing()
                        .frame(width: 120, height: 120)

                    VStack(spacing: 8) {
                        Text("AIが姿勢を分析中…")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(Theme.dark)

                        Text("数秒だけお待ちください")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 40)
            }
            .onAppear { startIfNeeded() }
            .onDisappear { pipelineTask?.cancel() }

        // ------------------------------------------------------
        // MARK: - 成功時 → PostureResultView へ移譲
        // ------------------------------------------------------
        case .success(let result, let skeleton, let report):
            PostureResultView(
                capturedImage: capturedImage,
                result: result,
                skeletonImage: skeleton,
                reportImage: report,
                onRetake: {
                    // カメラへ戻る（Flow を pop）
                    pipelineTask?.cancel()
                    onPop()
                },
                onClose: {
                    // 完全にホームへ戻る
                    pipelineTask?.cancel()
                    onPopToRoot()
                }
            )
            .navigationBarBackButtonHidden(true)

        // ------------------------------------------------------
        // MARK: - エラー UI
        // ------------------------------------------------------
        case .failure(let message):
            ZStack {
                Theme.gradientMain
                    .ignoresSafeArea()

                VStack(spacing: 28) {

                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)

                        Text("解析に失敗しました")
                            .font(.title3.weight(.bold))
                            .foregroundColor(Theme.dark)

                        Text(message)
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding()
                    .background(Theme.gradientCard)
                    .cornerRadius(Theme.cardRadius)
                    .shadow(color: Theme.shadow, radius: 7, y: 4)
                    .padding(.horizontal, 30)

                    GlassButton(
                        title: "再撮影する",
                        systemImage: "arrow.counterclockwise.circle.fill",
                        background: Theme.sub
                    ) {
                        pipelineTask?.cancel()
                        onPop()
                    }
                    .padding(.horizontal, 40)

                    GlassButton(
                        title: "ホームへ戻る",
                        systemImage: "house.fill",
                        background: Theme.dark.opacity(0.7)
                    ) {
                        pipelineTask?.cancel()
                        onPopToRoot()
                    }
                    .padding(.horizontal, 40)
                }
            }
            .onDisappear { pipelineTask?.cancel() }
        }
    }

    // MARK: - 初回一度だけ開始
    private func startIfNeeded() {
        guard !started else { return }
        started = true
        startPipeline()
    }

    // MARK: - AI解析パイプライン
    private func startPipeline() {
        pipelineTask = Task { [capturedImage] in
            do {
                try Task.checkCancellation()

                // ① AI姿勢解析（結果 + 指標）
                let (result, _) = try await analyzer.analyze(image: capturedImage)
                try Task.checkCancellation()

                // ② 骨格描画画像
                let skeleton = try analyzer.drawSkeleton(on: capturedImage)
                try Task.checkCancellation()

                // ③ 診断レポート画像
                let report = analyzer.generateReportImage(from: skeleton, result: result)
                try Task.checkCancellation()

                // ④ Firestoreへ保存（失敗は握りつぶし）
                try? await analyzer.saveResult(result)

                // ⑤ UI更新
                await MainActor.run {
                    state = .success(
                        result: result,
                        skeleton: skeleton,
                        report: report
                    )
                }

            } catch is CancellationError {
                print("⚠️ Pipeline canceled")
            } catch {
                await MainActor.run {
                    state = .failure(message: error.localizedDescription)
                }
            }
        }
    }
}
