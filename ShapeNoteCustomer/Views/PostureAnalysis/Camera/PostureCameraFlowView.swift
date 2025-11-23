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
                        cameraVM.freezeDisappear = false
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
                        // 再度カメラに戻る前にフラグ・状態をリセット
                        cameraVM.freezeDisappear = false
                        cameraVM.reset()
                        step = .camera
                    },
                    // OK → 分析へ
                    onConfirm: {
                        // Confirm に入った時点でセッションは既に止まっている想定
                        // ここで state を finished にして解析へ渡す
                        cameraVM.state = .finished
                        analysisImage = cameraVM.capturedImage
                        step = .analysis
                    }
                )
                .environmentObject(cameraVM)
                .onAppear {
                    // CameraView の onDisappear が終わった後なので、
                    // ここで初めて freezeDisappear を解除してよい
                    print("DEBUG: 📷 Confirm step appeared → freezeDisappear = false")
                    cameraVM.freezeDisappear = false
                }

            // =====================================================
            // MARK: - STEP 3: 分析画面
            // =====================================================
            case .analysis:
                if let image = analysisImage {
                    PostureAnalysisFlowView(
                        capturedImage: image,
                        // 「再撮影する」
                        onPop: {
                            cameraVM.reset()
                            step = .camera
                        },
                        // 「ホームに戻る」（フローを完全に閉じる）
                        onPopToRoot: {
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
        // Flow 開始時に一度だけクリーン状態にしておく
        .onAppear {
            print("DEBUG: 📷 FlowView appeared → cameraVM.reset()")
            cameraVM.freezeDisappear = false
            cameraVM.reset()
        }
    }
}
