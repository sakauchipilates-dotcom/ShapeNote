import SwiftUI
import ShapeCore

struct PostureCameraFlowView: View {

    @Environment(\.dismiss) private var dismiss

    @StateObject private var cameraVM = PostureCameraVM()

    private enum Step {
        case camera
        case confirm
        case analysis
    }

    @State private var step: Step = .camera
    @State private var analysisImage: UIImage? = nil

    var body: some View {
        Group {
            switch step {

            // =====================================================
            // MARK: - STEP 1: カメラ画面
            // =====================================================
            case .camera:
                PostureAnalysisCameraView(
                    onClose: {
                        // フローを閉じる前に状態をリセットしておくと安全
                        cameraVM.reset()
                        dismiss()
                    },
                    onCaptured: {
                        // 撮影が完了したら Confirm へ
                        step = .confirm
                    }
                )
                .environmentObject(cameraVM)

            // =====================================================
            // MARK: - STEP 2: 確認画面
            // =====================================================
            case .confirm:
                PostureCaptureConfirmView(
                    // 撮り直し → カメラへ戻る
                    onRetake: {
                        // セッション状態・カウンタなどをクリーンに戻してから
                        // カメラ画面に戻る
                        cameraVM.reset()
                        step = .camera
                    },
                    // OK → 分析へ
                    onConfirm: {
                        analysisImage = cameraVM.capturedImage
                        step = .analysis
                    }
                )
                .environmentObject(cameraVM)

            // =====================================================
            // MARK: - STEP 3: 分析画面
            // =====================================================
            case .analysis:
                if let image = analysisImage {
                    PostureAnalysisFlowView(
                        capturedImage: image,
                        // 「再撮影する」
                        onPop: {
                            // 分析 → カメラに戻るときも必ずリセット
                            cameraVM.reset()
                            step = .camera
                        },
                        // 「ホームに戻る」（フローを完全に閉じる）
                        onPopToRoot: {
                            // 終了前に状態をクリーンに
                            cameraVM.reset()
                            dismiss()
                        }
                    )
                } else {
                    // 万が一 analysisImage が nil のときのフォールバック
                    VStack(spacing: 16) {
                        Text("画像が見つかりませんでした。")
                        GlassButton(
                            title: "撮影に戻る",
                            systemImage: "arrow.counterclockwise.circle.fill",
                            background: Theme.sub
                        ) {
                            cameraVM.reset()
                            step = .camera
                        }
                    }
                }
            }
        }
        // ★ ここにあった onAppear { cameraVM.reset() } は削除
    }
}
