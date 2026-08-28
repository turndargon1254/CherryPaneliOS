import SwiftUI

@main
struct CherryPanelApp: App {
    @StateObject private var viewModel = AppViewModel.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(viewModel)
                .onAppear {
                    // Configure shared AppGroup for widget data sharing
                    // UserDefaults(suiteName: "group.com.cherrypanel.app")?.synchronize()
                }
        }
    }
}