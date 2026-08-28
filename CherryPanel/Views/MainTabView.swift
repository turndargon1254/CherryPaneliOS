import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = AppViewModel.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("仪表盘", systemImage: "server.rack")
            }
            .tag(0)
            
            NavigationStack {
                ConsoleView()
            }
            .tabItem {
                Label("控制台", systemImage: "terminal")
            }
            .tag(1)
            
            NavigationStack {
                FilesView()
            }
            .tabItem {
                Label("文件", systemImage: "folder")
            }
            .tag(2)
            
            NavigationStack {
                MetricsView()
            }
            .tabItem {
                Label("性能", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(3)
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gear")
            }
            .tag(4)
        }
        .accentColor(.cyan)
        .onAppear {
            // Start auto refresh
            viewModel.startAutoRefresh(interval: 30)
            // Start console log stream
            viewModel.startLogStream()
        }
        .onDisappear {
            viewModel.stopLogStream()
        }
    }
}