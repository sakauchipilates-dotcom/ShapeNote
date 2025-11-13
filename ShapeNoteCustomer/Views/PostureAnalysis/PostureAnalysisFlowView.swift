import SwiftUI

struct PostureAnalysisFlowView: View {
    let capturedImage: UIImage
    let onRetake: () -> Void      // カメラに戻る
    let onClose: () -> Void       // ホームに戻る

    @StateObject private var analyzer = PostureAnalyzer()
    @State private var state: AnalysisState = .loading
    @State private var started = false

    @State private var pipelineTask: Task<Void, Never>? = nil  // ← ★重要：キャンセル用

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
                guard !started else { return }   // 二重解析防止
                started = true
                startPipeline()
            }
            .onDisappear {
                // 画面遷移で FlowView が消えたら解析を中断
                pipelineTask?.cancel()
            }

        // MARK: - 解析成功 → 結果画面
        case .success(let result, let skeleton, let report):
            PostureResultView(
                capturedImage: capturedImage,
                result: result,
                skeletonImage: skeleton,
                reportImage: report,
                onRetake: {
                    pipelineTask?.cancel()
                    onRetake()
                },
                onClose: {
                    pipelineTask?.cancel()
                    onClose()
                }
            )

        // MARK: - 解析失敗
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
                        onRetake()
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
                        onClose()
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
                // Taskが途中でキャンセルされた場合に停止
                try Task.checkCancellation()

                // ① スコア解析
                let analysis = try await analyzer.analyze(image: capturedImage)

                try Task.checkCancellation()

                // ② 骨格描画
                let skeleton = try analyzer.drawSkeleton(on: capturedImage)

                try Task.checkCancellation()

                // ③ レポート生成
                let report = analyzer.generateReportImage(from: skeleton, result: analysis)

                try Task.checkCancellation()

                // ④ Firestore 保存
                try? await analyzer.saveResult(analysis)

                // ⑤ UI更新
                await MainActor.run {
                    state = .success(result: analysis, skeleton: skeleton, report: report)
                }

            } catch is CancellationError {
                // キャンセルされた場合は何もしない
                print("⚠️ Pipeline canceled")
            } catch {
                await MainActor.run {
                    state = .failure(message: error.localizedDescription)
                }
            }
        }
    }
}
