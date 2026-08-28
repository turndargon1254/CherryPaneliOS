import SwiftUI
import Charts

struct MetricsView: View {
    @StateObject private var viewModel = AppViewModel.shared
    @State private var timeRange: TimeRange = .oneHour
    
    enum TimeRange: String, CaseIterable {
        case oneHour = "1h"
        case sixHours = "6h"
        case twentyFourHours = "24h"
    }
    
    var body: some View {
        List {
            // Time Range Selector
            Section {
                Picker("时间范围", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 8)
            }
            
            // Summary Cards
            Section {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricCard(
                        title: "TPS",
                        value: String(format: "%.1f", viewModel.serverMetrics?.tps ?? 0),
                        unit: "/ 20.0",
                        icon: "speedometer",
                        color: .cyan,
                        progress: min((viewModel.serverMetrics?.tps ?? 0) / 20.0, 1.0)
                    )
                    
                    MetricCard(
                        title: "CPU",
                        value: String(format: "%.1f", viewModel.serverMetrics?.cpuPercent ?? 0),
                        unit: "%",
                        icon: "cpu",
                        color: .orange,
                        progress: (viewModel.serverMetrics?.cpuPercent ?? 0) / 100.0
                    )
                    
                    MetricCard(
                        title: "内存",
                        value: String(format: "%.1f", viewModel.serverMetrics?.memoryPercent ?? 0),
                        unit: "%",
                        icon: "memorychip",
                        color: .green,
                        progress: (viewModel.serverMetrics?.memoryPercent ?? 0) / 100.0
                    )
                    
                    MetricCard(
                        title: "JVM 堆",
                        value: String(format: "%.1f", viewModel.serverMetrics?.jvmHeapPercent ?? 0),
                        unit: "%",
                        icon: "cube.fill",
                        color: .purple,
                        progress: (viewModel.serverMetrics?.jvmHeapPercent ?? 0) / 100.0
                    )
                }
                .padding(.vertical, 8)
            }
            
            // Charts
            Section("趋势图表") {
                if let history = viewModel.crashStatsData?.byType { // Using crash stats as placeholder for history
                    // In real implementation, you'd have metrics history here
                    ChartPlaceholderView()
                } else {
                    ChartPlaceholderView()
                }
            }
            
            // Detailed Stats
            Section("详细统计") {
                if let stats = viewModel.serverMetrics, let status = viewModel.serverStatus {
                    DetailRow(label: "JVM 堆内存", value: String(format: "%.1f GB / %.1f GB", stats.jvmHeapUsedMB/1024, stats.jvmHeapMaxMB/1024))
                    DetailRow(label: "JVM 堆使用率", value: String(format: "%.1f%%", stats.jvmHeapPercent))
                    DetailRow(label: "MSPT", value: String(format: "%.1f ms", stats.mspt))
                    DetailRow(label: "磁盘空间", value: String(format: "%.1f GB 可用 / %.1f GB 总计", stats.diskFreeGB, stats.diskTotalGB))
                    DetailRow(label: "磁盘使用率", value: String(format: "%.1f%%", stats.diskPercent))
                    DetailRow(label: "服务器目录", value: viewModel.statistics?.serverDir ?? "--")
                    DetailRow(label: "JAR 文件", value: viewModel.statistics?.jarFile ?? "--")
                    DetailRow(label: "运行状态", value: status.running ? "🟢 运行中" : "🔴 已停止")
                    DetailRow(label: "进程 ID", value: status.pid.map(String.init) ?? "--")
                    DetailRow(label: "启动时间", value: status.startTime?.formatted() ?? "--")
                    DetailRow(label: "运行时长", value: status.uptime)
                }
            }
        }
        .navigationTitle("性能监控")
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

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

struct ChartPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("历史数据图表")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("连接后端后将显示实时趋势图表")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}