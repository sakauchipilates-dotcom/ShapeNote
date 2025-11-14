import SwiftUI
import FirebaseAuth
import ShapeCore

struct CustomerRootView: View {

    @State private var selectedTab = 0

    // 🔥 NavigationStack の path（PostureRoute 用）
    @State private var path: [PostureRoute] = []

    @EnvironmentObject var appState: CustomerAppState
    @StateObject private var contactUnreadVM = CustomerContactUnreadVM()

    var body: some View {
        NavigationStack(path: $path) {

            TabView(selection: $selectedTab) {

                // MARK: - 記録
                CalendarView()
                    .tabItem {
                        Label("記録", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(0)

                // MARK: - チャット
                ChatListView()
                    .tabItem {
                        Label("チャット", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                    .tag(1)

                // MARK: - エクササイズ
                ExerciseSheetView()
                    .tabItem {
                        Label("エクササイズ", systemImage: "figure.walk.circle")
                    }
                    .tag(2)

                // MARK: - 姿勢分析
                PostureAnalysisView(
                    push: { route in path.append(route) }
                )
                .tabItem {
                    Label("姿勢分析", systemImage: "viewfinder.circle")
                }
                .tag(3)

                // MARK: - マイページ
                MyPageView()
                    .tabItem {
                        Label("マイページ", systemImage: "person.crop.circle")
                    }
                    .badge(contactUnreadVM.unreadCount)
                    .tag(4)
            }
            .accentColor(.primary)
            .environmentObject(contactUnreadVM)

            // MARK: - pushDestination（画面一元管理）
            .navigationDestination(for: PostureRoute.self) { route in
                switch route {

                // ------------------------
                // ガイド
                // ------------------------
                case .guide:
                    PostureGuideView(
                        onPush: { r in path.append(r) },
                        onPop:  {
                            if !path.isEmpty { path.removeLast() }
                        }
                    )

                // ------------------------
                // カメラ
                // ------------------------
                case .camera:
                    PostureAnalysisCameraView(
                        onPush: { r in path.append(r) },
                        onPop:  {
                            if !path.isEmpty { path.removeLast() }
                        }
                    )

                // ------------------------
                // AIフロー（解析中 → 結果へ遷移）
                // ------------------------
                case .flow(let captured):
                    PostureAnalysisFlowView(
                        capturedImage: captured,
                        onPush: { r in path.append(r) },
                        onPop: {
                            if !path.isEmpty { path.removeLast() }
                        },
                        onPopToRoot: {
                            path.removeAll()
                        }
                    )

                // ------------------------
                // 結果
                // ------------------------
                case .result(let captured, let result, let skeleton, let report):
                    PostureResultView(
                        capturedImage: captured,
                        result: result,
                        skeletonImage: skeleton,
                        reportImage: report,

                        onRetake: {
                            // Flow に戻る
                            if !path.isEmpty { path.removeLast() }
                        },

                        onClose: {
                            // 完全リセットしてタブ 0 に戻す
                            path.removeAll()
                            selectedTab = 0
                        }
                    )
                }
            }
        }
    }
}

#Preview {
    CustomerRootView()
        .environmentObject(CustomerAppState())
}
