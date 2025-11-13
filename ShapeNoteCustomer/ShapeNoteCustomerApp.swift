import SwiftUI
import ShapeCore

@main
struct ShapeNoteCustomerApp: App {
    @StateObject private var appState  = CustomerAppState()
    @StateObject private var profileVM = ProfileImageVM()

    init() {
        ShapeCore.initialize()
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
