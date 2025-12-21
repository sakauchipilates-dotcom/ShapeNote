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
                        cameraVM.freezeDisappear = false
                        cameraVM.reset()
                        dismiss()
                    },
                    onCaptured: {
                        step = .integratedAnalysis
                    }
                )
                .environmentObject(cameraVM)

            case .integratedAnalysis:
                PostureMultiAnalysisView(
                    shots: cameraVM.shots,
                    onRetakeAll: {
                        cameraVM.freezeDisappear = false
                        cameraVM.reset()
                        step = .camera
                    },
                    onClose: {
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
