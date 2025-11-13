import SwiftUI
import FirebaseAuth
import ShapeCore

struct AdminRootView: View {
    @StateObject private var contactVM = ContactUnreadVM()
    @EnvironmentObject var appState: AdminAppState
    private let auth = AuthHandler.shared

    enum Tab: Hashable { case dashboard, chat, exercise, members, mypage }
    @State private var selectedTab: Tab = .dashboard

    var body: some View {
        ZStack {
            // ✅ テーマ背景（黒化対策済）
            Theme.main.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                AdminHomeView()
                    .tabItem { Label("ダッシュボード", systemImage: "house") }
                    .tag(Tab.dashboard)

                AdminChatListView()
                    .tabItem { Label("チャット", systemImage: "bubble.left.and.bubble.right") }
                    .tag(Tab.chat)

                AdminExerciseSheetView()
                    .tabItem { Label("エクササイズ", systemImage: "figure.strengthtraining.traditional") }
                    .tag(Tab.exercise)

                AdminMemberListView()
                    .tabItem { Label("会員管理", systemImage: "person.3") }
                    .tag(Tab.members)

                AdminMyPageView()
                    .tabItem { Label("マイページ", systemImage: "person.circle") }
                    .badge(contactVM.unreadCount)
                    .tag(Tab.mypage)
            }
            .environmentObject(contactVM)
        }
    }
}
