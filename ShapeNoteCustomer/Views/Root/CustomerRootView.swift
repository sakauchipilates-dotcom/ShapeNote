import SwiftUI
import FirebaseAuth
import ShapeCore

struct CustomerRootView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var appState: CustomerAppState
    @StateObject private var contactUnreadVM = CustomerContactUnreadVM()
    private let auth = AuthHandler.shared

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {

                // MARK: - 記録（旧：カレンダー）
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

                // MARK: - 姿勢分析（旧：予約）
                PostureAnalysisView()
                    .tabItem {
                        Label("姿勢分析", systemImage: "viewfinder.circle")
                    }
                    .tag(3)

                // MARK: - マイページ（未読バッジ付き）
                MyPageView()
                    .tabItem {
                        Label("マイページ", systemImage: "person.crop.circle")
                    }
                    .badge(contactUnreadVM.unreadCount)
                    .tag(4)
            }
            .accentColor(.primary)
            .environmentObject(contactUnreadVM)
        }
    }
}

#Preview {
    CustomerRootView()
        .environmentObject(CustomerAppState())
}
