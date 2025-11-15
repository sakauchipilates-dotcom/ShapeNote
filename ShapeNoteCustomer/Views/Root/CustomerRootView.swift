import SwiftUI
import ShapeCore

struct CustomerRootView: View {

    @State private var selectedTab = 0

    var body: some View {

        TabView(selection: $selectedTab) {

            CalendarView()
                .tabItem { Label("記録", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(0)

            ChatListView()
                .tabItem { Label("チャット", systemImage: "bubble.left.and.bubble.right") }
                .tag(1)

            ExerciseSheetView()
                .tabItem { Label("エクササイズ", systemImage: "figure.walk.circle") }
                .tag(2)

            // ★撮影フローまとめ画面に差し替え
            PostureAnalysisEntryView()
                .tabItem { Label("姿勢分析", systemImage: "viewfinder.circle") }
                .tag(3)

            MyPageView()
                .tabItem { Label("マイページ", systemImage: "person.crop.circle") }
                .tag(4)
        }
    }
}
