import SwiftUI
import ShapeCore
import UIKit

@main
struct ShapeNoteAdminApp: App {
    @StateObject private var appState = AdminAppState()
    @StateObject private var authVM = AuthViewModel()

    init() {
        ShapeCore.initialize()
        configureUIAppearance() // ✅ UIKit側の外観統一
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.user != nil {
                    AdminRootView()
                        .environmentObject(appState)
                        .environmentObject(authVM)
                } else {
                    AdminLoginView()
                        .environmentObject(appState)
                        .environmentObject(authVM)
                }
            }
            // ✅ アプリ全体ライトモード固定
            .preferredColorScheme(.light)
        }
    }
}

// MARK: - UIKit外観統一設定
private func configureUIAppearance() {
    // MARK: TabBar 設定
    let tabAppearance = UITabBarAppearance()
    tabAppearance.configureWithOpaqueBackground()
    tabAppearance.backgroundColor = UIColor(Theme.main)

    // アイコン・テキストの色指定
    let itemAppearance = UITabBarItemAppearance()
    itemAppearance.normal.iconColor = UIColor(Theme.dark).withAlphaComponent(0.4)
    itemAppearance.normal.titleTextAttributes = [
        .foregroundColor: UIColor(Theme.dark).withAlphaComponent(0.4)
    ]
    itemAppearance.selected.iconColor = UIColor(Theme.sub)
    itemAppearance.selected.titleTextAttributes = [
        .foregroundColor: UIColor(Theme.sub)
    ]

    // 適用
    tabAppearance.stackedLayoutAppearance = itemAppearance
    tabAppearance.inlineLayoutAppearance = itemAppearance
    tabAppearance.compactInlineLayoutAppearance = itemAppearance

    UITabBar.appearance().standardAppearance = tabAppearance
    UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    UITabBar.appearance().barStyle = .default

    // MARK: NavigationBar 設定
    let navAppearance = UINavigationBarAppearance()
    navAppearance.configureWithOpaqueBackground()
    navAppearance.backgroundColor = UIColor.white
    navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Theme.dark)]
    navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.dark)]
    UINavigationBar.appearance().standardAppearance = navAppearance
    UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    UINavigationBar.appearance().compactAppearance = navAppearance
    UINavigationBar.appearance().barStyle = .default

    // MARK: 背景透明化（必要ビューのみ）
    UIScrollView.appearance().backgroundColor = .clear
    UITableView.appearance().backgroundColor = .clear
    UICollectionView.appearance().backgroundColor = .clear
}
