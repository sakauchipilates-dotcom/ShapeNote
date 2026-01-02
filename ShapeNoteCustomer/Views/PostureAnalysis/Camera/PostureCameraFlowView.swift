import SwiftUI
import ShapeCore
import FirebaseAuth
import FirebaseFirestore

struct PostureCameraFlowView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: CustomerAppState

    @StateObject private var cameraVM = PostureCameraVM()

    private enum Step {
        case camera
        case integratedAnalysis
    }

    @State private var step: Step = .camera

    // Gate UI（保険）
    @State private var showGateAlert: Bool = false
    @State private var gateMessage: String = ""

    private let db = Firestore.firestore()

    var body: some View {
        Group {
            switch step {

            case .camera:
                PostureAnalysisCameraView(
                    onClose: { closeAll() },
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
                        cameraVM.freezeDisappear = false
                        cameraVM.reset()
                        step = .camera
                    },
                    onClose: {
                        Task {
                            await markPostureUsageConsumedIfNeeded()
                            closeAll()
                        }
                    }
                )
            }
        }
        .onAppear {
            cameraVM.freezeDisappear = false
            cameraVM.reset()

            // ✅ EntryViewで弾いていても、ここでも二重チェック（安全策）
            Task { await guardMonthlyLimitIfNeeded() }
        }
        .alert("利用制限", isPresented: $showGateAlert) {
            Button("OK", role: .cancel) { closeAll() }
        } message: {
            Text(gateMessage)
        }
    }

    // MARK: - Close helper
    private func closeAll() {
        cameraVM.freezeDisappear = false
        cameraVM.reset()
        dismiss()
    }

    // MARK: - Monthly limit guard (double check)
    private func guardMonthlyLimitIfNeeded() async {
        // Premiumは制限なし
        guard !appState.subscriptionState.isPremium else { return }

        // Free：当月に既に撮影済みならここでも弾く
        let last = await fetchLastPostureCapturedAt()
        let can = SNUsageLimit.canCapturePostureFree(lastCaptured: last)

        guard can else {
            let reset = SNUsageLimit.nextPostureResetDate()
            if let reset {
                let f = DateFormatter()
                f.locale = Locale(identifier: "ja_JP")
                f.calendar = Calendar(identifier: .gregorian)
                f.dateFormat = "M月d日"
                gateMessage = "無料会員は姿勢分析の撮影は月1回までです。\n次回は \(f.string(from: reset)) から撮影できます。"
            } else {
                gateMessage = "無料会員は姿勢分析の撮影は月1回までです。次回リセット日を確認できませんでした。"
            }
            showGateAlert = true
            return
        }
    }

    private func fetchLastPostureCapturedAt() async -> Date? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            let data = snap.data() ?? [:]
            let usage = data["usage"] as? [String: Any] ?? [:]
            let ts = usage["postureLastCapturedAt"] as? Timestamp
            return ts?.dateValue()
        } catch {
            print("⚠️ fetchLastPostureCapturedAt failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Consume usage (Free only)
    /// 統合解析完了で閉じるタイミングで “今月分を消費確定”
    private func markPostureUsageConsumedIfNeeded() async {
        guard !appState.subscriptionState.isPremium else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("users").document(uid).setData([
                "usage": [
                    "postureLastCapturedAt": FieldValue.serverTimestamp()
                ]
            ], merge: true)

            print("✅ posture usage consumed (free): users/\(uid).usage.postureLastCapturedAt")
        } catch {
            // ここが失敗すると “制限が効かない” 側に倒れる可能性があるのでログ必須
            print("⚠️ markPostureUsageConsumed failed: \(error.localizedDescription)")
        }
    }
}
