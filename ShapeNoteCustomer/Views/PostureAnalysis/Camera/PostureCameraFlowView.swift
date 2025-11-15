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

            case .camera:
                PostureAnalysisCameraView(
                    onClose: { dismiss() },
                    onCaptured: {
                        step = .confirm
                    }
                )
                .environmentObject(cameraVM)

            case .confirm:
                PostureCaptureConfirmView(
                    onRetake: {
                        step = .camera
                    },
                    onConfirm: {
                        analysisImage = cameraVM.capturedImage
                        step = .analysis
                    }
                )
                .environmentObject(cameraVM)

            case .analysis:
                if let image = analysisImage {
                    PostureAnalysisFlowView(
                        capturedImage: image,
                        onPop: {
                            cameraVM.reset()
                            step = .camera
                        },
                        onPopToRoot: {
                            dismiss()
                        }
                    )
                } else {
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
    }
}
