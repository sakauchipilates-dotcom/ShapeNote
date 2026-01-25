import SwiftUI
import ShapeCore
import FirebaseAuth
import FirebaseFirestore

struct CustomerRootView: View {

    @EnvironmentObject private var appState: CustomerAppState
    @State private var selectedTab: Int = 0

    @StateObject private var weightManager = WeightManager()

    // Legal 同意用 Binding（EnvironmentObject を直接 $ で使わない）
    private var needsLegalConsentBinding: Binding<Bool> {
        Binding(
            get: { appState.needsLegalConsent },
            set: { appState.needsLegalConsent = $0 }
        )
    }

    var body: some View {

        // =========================
        // ✅ 通常ルート（TabView）
        // =========================
        TabView(selection: $selectedTab) {

            CalendarView(weightManager: weightManager)
                .tabItem { Label("記録", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(0)

            CommunityView()
                .tabItem { Label("コミュニティ", systemImage: "person.3.fill") }
                .tag(1)

            ExerciseSheetView()
                .tabItem { Label("エクササイズ", systemImage: "figure.walk.circle") }
                .tag(2)

            PostureAnalysisEntryView()
                .tabItem { Label("姿勢分析", systemImage: "viewfinder.circle") }
                .tag(3)

            MyPageView()
                .tabItem { Label("マイページ", systemImage: "person.crop.circle") }
                .tag(4)
        }
        // =========================
        // 初期ロード
        // =========================
        .task {
            await appState.refreshLegalConsentState()
            await appState.refreshSubscriptionState()
            await weightManager.loadWeights()

            weightManager.setSubscriptionState(appState.subscriptionState)
        }
        .onReceive(appState.$subscriptionState) { state in
            weightManager.setSubscriptionState(state)
        }
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == 0 else { return }
            Task { await weightManager.loadWeights() }
        }
        // =========================
        // Legal 同意
        // =========================
        .fullScreenCover(isPresented: needsLegalConsentBinding) {
            LegalConsentView(
                onAgree: {
                    // 1) 先に閉じる（レビュー機での無反応対策）
                    appState.needsLegalConsent = false

                    // 2) Firestore 保存は裏で
                    Task {
                        await saveLatestLegalConsent()
                        await appState.refreshLegalConsentState()
                    }
                }
            )
            .interactiveDismissDisabled(true)
        }
    }

    // MARK: - Save legal consent (Root側で確実に保存)
    @MainActor
    private func saveLatestLegalConsent() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }

        do {
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .setData([
                    "legal": [
                        "privacyVersion": LegalDocuments.privacyPolicyVersion,
                        "termsVersion": LegalDocuments.termsVersion,
                        "acceptedAt": FieldValue.serverTimestamp()
                    ]
                ], merge: true)

            print("✅ Legal同意を保存しました (Root)")

        } catch {
            // 保存失敗時は安全側へ
            appState.needsLegalConsent = true
            print("⚠️ Legal同意保存エラー (Root): \(error.localizedDescription)")
        }
    }
}
