import SwiftUI

struct PostureAnalysisFlowView: View {

    let capturedImage: UIImage

    // 🔥 Navigation を外部（CustomerRoot）から受け取る
    let onPush: (PostureRoute) -> Void
    let onPop: () -> Void            // Camera へ戻る
    let onPopToRoot: () -> Void      // Home へ戻る

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

        // MARK: - ローディング画面
        case .loading:
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("AIが姿勢を分析中…")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
            .onAppear {
                guard !started else { return }
                started = true
                startPipeline()
            }
            .onDisappear {
                pipelineTask?.cancel()
            }

        // MARK: - 成功（→ ResultView に push）
        case .success(let result, let skeleton, let report):
            PostureResultView(
                capturedImage: capturedImage,
                result: result,
                skeletonImage: skeleton,
                reportImage: report,
                onRetake: {
                    // 🔥 Flow → Camera に戻る
                    pipelineTask?.cancel()
                    onPop()
                },
                onClose: {
                    // 🔥 Home に戻る
                    pipelineTask?.cancel()
                    onPopToRoot()
                }
            )
            .navigationBarBackButtonHidden(true)

        // MARK: - 失敗画面
        case .failure(let message):
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 20) {

                    Text("解析に失敗しました。")
                        .foregroundColor(.white)
                        .font(.headline)

                    Text(message)
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Button {
                        pipelineTask?.cancel()
                        onPop()   // → Camera
                    } label: {
                        Label("再撮影する", systemImage: "arrow.counterclockwise.circle.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 40)
                    }

                    Button {
                        pipelineTask?.cancel()
                        onPopToRoot()
                    } label: {
                        Label("ホームへ戻る", systemImage: "house.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.4))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 40)
                    }
                }
            }
            .onDisappear {
                pipelineTask?.cancel()
            }
        }
    }

    // MARK: - 解析パイプライン
    private func startPipeline() {

        pipelineTask = Task { [capturedImage] in
            do {
                try Task.checkCancellation()

                // ① スコア解析
                let analysis = try await analyzer.analyze(image: capturedImage)
                try Task.checkCancellation()

                // ② 骨格画像
                let skeleton = try analyzer.drawSkeleton(on: capturedImage)
                try Task.checkCancellation()

                // ③ レポート画像
                let report = analyzer.generateReportImage(from: skeleton, result: analysis)
                try Task.checkCancellation()

                // ④ Firestore 保存（失敗は無視）
                try? await analyzer.saveResult(analysis)

                // ⑤ UI更新（成功 → 自動的に ResultView に切り替わる）
                await MainActor.run {
                    state = .success(result: analysis, skeleton: skeleton, report: report)
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
