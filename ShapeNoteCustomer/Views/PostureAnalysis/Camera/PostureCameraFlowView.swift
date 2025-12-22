import SwiftUI
import ShapeCore

struct PostureCameraFlowView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraVM = PostureCameraVM()

    private enum Step {
        case camera
        case integratedAnalysis
    }

    @State private var step: Step = .camera

    var body: some View {
        Group {
            switch step {

            case .camera:
                PostureAnalysisCameraView(
                    onClose: {
                        // 終了は安全に全リセット
                        cameraVM.freezeDisappear = false
                        cameraVM.reset()
                        dismiss()
                    },
                    onCaptured: {
                        // 4枚揃ったら統合解析へ
                        step = .integratedAnalysis
                    }
                )
                .environmentObject(cameraVM)

            case .integratedAnalysis:
                PostureMultiAnalysisView(
                    shots: cameraVM.shots,
                    onRetakeAll: {
                        // 4枚まとめて撮り直し
                        cameraVM.freezeDisappear = false
                        cameraVM.reset()
                        step = .camera
                    },
                    onClose: {
                        // 完全に閉じる
                        cameraVM.freezeDisappear = false
                        cameraVM.reset()
                        dismiss()
                    }
                )
            }
        }
        .onAppear {
            cameraVM.freezeDisappear = false
            cameraVM.reset()
        }
    }
}
