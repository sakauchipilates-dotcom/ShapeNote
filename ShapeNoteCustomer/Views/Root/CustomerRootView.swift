import SwiftUI
import ShapeCore

struct CustomerRootView: View {

    @EnvironmentObject private var appState: CustomerAppState
    @State private var selectedTab = 0

    // Rootで1つ生成して使い回す（正解）
    @StateObject private var weightManager = WeightManager()

    var body: some View {
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
        .task {
            await appState.refreshLegalConsentState()
            await appState.refreshSubscriptionState()
            await weightManager.loadWeights()

            // ✅ 初回注入
            weightManager.setSubscriptionState(appState.subscriptionState)
        }
        .onReceive(appState.$subscriptionState) { state in
            // ✅ subscription が変わったら VM に反映
            weightManager.setSubscriptionState(state)
        }
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == 0 else { return }
            Task { await weightManager.loadWeights() }
        }
        .fullScreenCover(isPresented: $appState.needsLegalConsent) {
            LegalConsentView(
                onAgree: { Task { await appState.acceptLatestLegal() } }
            )
            .interactiveDismissDisabled(true)
        }
    }
}
