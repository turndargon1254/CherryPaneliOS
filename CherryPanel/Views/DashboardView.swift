import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = AppViewModel.shared
    @State private var showingStartConfirm = false
    @State private var showingStopConfirm = false
    @State private var showingRestartConfirm = false
    
    var body: some View {
        List {
            // Server Status Section
            Section("服务器状态") {
                StatusRow(title: "运行状态", value: viewModel.serverStatus?.running == true ? "🟢 运行中" : "🔴 已停止", icon: "server.rack", color: viewModel.serverStatus?.running == true ? .green : .red)
                StatusRow(title: "运行时间", value: viewModel.serverStatus?.uptime ?? "--", icon: "clock")
                StatusRow(title: "PID", value: viewModel.serverStatus?.pid.map(String.init) ?? "--", icon: "number")
                StatusRow(title: "启动时间", value: viewModel.serverStatus?.startTime?.formatted() ?? "--", icon: "calendar")
            }
            
            // Players Section
            Section("玩家") {
                StatusRow(title: "在线人数", value: "\(viewModel.serverMetrics?.playersOnline ?? 0) / \(viewModel.serverMetrics?.playersMax ?? 0)", icon: "person.2.fill", color: .blue)
                if let players = viewModel.serverMetrics?.playersList, !players.isEmpty {
                    ForEach(players, id: \.self) { player in
                        Label(player, systemImage: "person.fill")
                            .font(.subheadline)
                    }
                }
            }
            
            // Performance Section
            Section("性能指标") {
                StatusRow(title: "TPS", value: String(format: "%.1f", viewModel.serverMetrics?.tps ?? 0), icon: "speedometer", color: (viewModel.serverMetrics?.tps ?? 0) >= 19.5 ? .green : ((viewModel.serverMetrics?.tps ?? 0) >= 18 ? .yellow : .red))
                StatusRow(title: "MSPT", value: String(format: "%.1f ms", viewModel.serverMetrics?.mspt ?? 0), icon: "timer", color: (viewModel.serverMetrics?.mspt ?? 0) <= 50 ? .green : .orange)
                StatusRow(title: "CPU", value: String(format: "%.1f%%", viewModel.serverMetrics?.cpuPercent ?? 0), icon: "cpu", color: (viewModel.serverMetrics?.cpuPercent ?? 0) < 70 ? .green : .orange)
                StatusRow(title: "内存", value: String(format: "%.1f GB / %.1f GB", (viewModel.serverMetrics?.memoryUsedMB ?? 0)/1024, (viewModel.serverMetrics?.memoryMaxMB ?? 0)/1024), icon: "memorychip")
                StatusRow(title: "JVM 堆", value: String(format: "%.1f GB / %.1f GB", (viewModel.serverMetrics?.jvmHeapUsedMB ?? 0)/1024, (viewModel.serverMetrics?.jvmHeapMaxMB ?? 0)/1024), icon: "cube.fill")
                StatusRow(title: "磁盘", value: String(format: "%.1f GB 可用 / %.1f GB 总计", viewModel.serverMetrics?.diskFreeGB ?? 0, viewModel.serverMetrics?.diskTotalGB ?? 0), icon: "externaldrive.fill")
            }
            
            // Quick Actions
            Section("快速操作") {
                HStack(spacing: 12) {
                    ActionButton(title: "启动", icon: "play.fill", color: .green, disabled: viewModel.serverStatus?.running == true) {
                        showingStartConfirm = true
                    }
                    ActionButton(title: "停止", icon: "stop.fill", color: .red, disabled: viewModel.serverStatus?.running != true) {
                        showingStopConfirm = true
                    }
                    ActionButton(title: "重启", icon: "arrow.clockwise", color: .orange, disabled: false) {
                        showingRestartConfirm = true
                    }
                }
                .confirmationDialog("确定要启动服务器吗？", isPresented: $showingStartConfirm) {
                    Button("确定", role: .destructive) { Task { await viewModel.startServer() } }
                    Button("取消", role: .cancel) {}
                }
                .confirmationDialog("确定要停止服务器吗？", isPresented: $showingStopConfirm) {
                    Button("确定", role: .destructive) { Task { await viewModel.stopServer() } }
                    Button("取消", role: .cancel) {}
                }
                .confirmationDialog("确定要重启服务器吗？", isPresented: $showingRestartConfirm) {
                    Button("确定", role: .destructive) { Task { await viewModel.restartServer() } }
                    Button("取消", role: .cancel) {}
                }
            }
        }
        .navigationTitle("CherryPanel")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await viewModel.refreshAllData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .refreshable {
            await viewModel.refreshAllData()
        }
    }
}

struct StatusRow: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var disabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(disabled ? color.opacity(0.3) : color)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(disabled)
    }
}