import SwiftUI
import ShapeCore
import FirebaseAuth
import FirebaseFirestore

struct PostureAnalysisEntryView: View {

    @EnvironmentObject private var appState: CustomerAppState

    // ガイド表示
    @State private var showGuide: Bool = false
    // カメラフロー
    @State private var showCameraFlow: Bool = false

    // Gate UI
    @State private var showGateAlert: Bool = false
    @State private var gateMessage: String = ""

    private let db = Firestore.firestore()

    var body: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            VStack(spacing: 28) {

                Spacer().frame(height: 48)

                Image(systemName: "figure.stand")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .foregroundColor(Theme.sub)

                Text("AI姿勢分析を始めましょう")
                    .font(.title3.bold())
                    .foregroundColor(Theme.dark)

                privacyCard
                    .padding(.horizontal, 24)

                Spacer()

                Button {
                    Task { await handleTapStart() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 20, weight: .semibold))
                        Text("撮影を開始")
                            .font(.headline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [
                                Theme.sub,
                                Theme.sub.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Theme.shadow, radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .alert("利用制限", isPresented: $showGateAlert) {
            Button("OK", role: .cancel) {}
            // ※あとで課金導線を入れるならここにボタン追加
            // Button("プレミアムを確認") { /* paywall */ }
        } message: {
            Text(gateMessage)
        }
        .fullScreenCover(isPresented: $showGuide) {
            PostureCaptureGuideView(
                onClose: { showGuide = false },
                onGoCamera: {
                    showGuide = false
                    showCameraFlow = true
                }
            )
        }
        .fullScreenCover(isPresented: $showCameraFlow) {
            PostureCameraFlowView()
        }
    }

    // MARK: - Tap handler
    private func handleTapStart() async {

        // ✅ Premium は制限なし（現時点の仕様）
        if appState.subscriptionState.isPremium {
            showGuide = true
            return
        }

        // ✅ Free は月1回（Firestoreの usage を参照）
        let lastCaptured = await fetchLastPostureCapturedAt()

        let can = SNUsageLimit.canCapturePostureFree(lastCaptured: lastCaptured)
        if can {
            showGuide = true
            return
        }

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
    }

    /// users/{uid}/usage/postureLastCapturedAt を読む
    private func fetchLastPostureCapturedAt() async -> Date? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }

        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            let data = snap.data() ?? [:]
            let usage = data["usage"] as? [String: Any] ?? [:]
            let ts = usage["postureLastCapturedAt"] as? Timestamp
            return ts?.dateValue()
        } catch {
            // 取得できない場合は「無料制限を厳密にかける」か「通す」か設計があるが、
            // 課金誤開放を避けるなら “通す” より “止める” が安全。
            // ただしUX悪化するので、まずは通す（=nil扱い）にしておく。
            print("⚠️ fetchLastPostureCapturedAt failed: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - 注意事項カード
private extension PostureAnalysisEntryView {

    var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            noteRow(
                icon: safeSFSymbol(preferred: "camera.front.fill", fallback: "camera.fill"),
                text: "フロント（内側）カメラを使用します"
            )

            noteRow(
                icon: "lock.fill",
                text: "撮影画像は端末内のみで処理されます"
            )

            noteRow(
                icon: "nosign",
                text: "画像の保存・送信は行われません"
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: Theme.shadow, radius: 10, x: 0, y: 6)
    }

    func noteRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.sub.opacity(0.85))
                .frame(width: 18)

            Text(text)
                .font(.footnote)
                .foregroundColor(Theme.dark.opacity(0.85))

            Spacer(minLength: 0)
        }
    }

    func safeSFSymbol(preferred: String, fallback: String) -> String {
        if UIImage(systemName: preferred) != nil { return preferred }
        return fallback
    }
}
