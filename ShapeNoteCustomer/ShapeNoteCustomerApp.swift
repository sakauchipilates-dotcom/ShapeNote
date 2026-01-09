import SwiftUI
import ShapeCore

@main
struct ShapeNoteCustomerApp: App {

    @StateObject private var appState: CustomerAppState
    @StateObject private var profileVM: ProfileImageVM

    init() {
        // ✅ 先に Firebase / ShapeCore 初期化（ここが最重要）
        ShapeCore.initialize()

        // ✅ 初期化が終わってから StateObject を生成
        _appState = StateObject(wrappedValue: CustomerAppState())
        _profileVM = StateObject(wrappedValue: ProfileImageVM())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLoggedIn {
                    CustomerRootView()
                } else {
                    CustomerLoginView()
                }
            }
            .environmentObject(appState)
            .environmentObject(profileVM)
        }
    }
}
