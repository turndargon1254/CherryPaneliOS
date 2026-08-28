import SwiftUI

struct CrashView: View {
    @StateObject private var viewModel = AppViewModel.shared
    @State private var timeRange: TimeRange = .oneDay
    @State private var searchText = ""
    @State private var selectedReport: CrashReport?
    @State private var showSettings = false
    @State private var settings = CrashSettings()
    
    enum TimeRange: String, CaseIterable {
        case oneHour = "1h"
        case sixHours = "6h"
        case oneDay = "24h"
        case sevenDays = "7d"
    }
    
    struct CrashSettings {
        var maxCrashesPerWindow = 3
        var crashWindowSeconds = 300
        var checkInterval = 5
    }
    
    private var hours: Int {
        switch timeRange {
        case .oneHour: return 1
        case .sixHours: return 6
        case .oneDay: return 24
        case .sevenDays: return 168
        }
    }
    
    var filteredReports: [CrashReport] {
        if searchText.isEmpty {
            return viewModel.crashReports
        }
        return viewModel.crashReports.filter { report in
            report.crashType.localizedCaseInsensitiveContains(searchText) ||
            report.message.localizedCaseInsensitiveContains(searchText) ||
            report.stackTrace.localizedCaseInsensitiveContains(searchText) ||
            report.suggestedFix.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        List {
            timeRangeSection
            statsSection
            typeDistributionSection
            reportHeaderSection
            reportListSection
        }
        .navigationTitle("崩溃报告")
        .searchable(text: $searchText, prompt: "搜索类型、消息、堆栈...")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    ForEach(CrashView.TimeRange.allCases, id: \.self) { range in
                        Button(action: { timeRange = range }) {
                            Label(range.rawValue, systemImage: timeRange == range ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label(timeRange.rawValue, systemImage: "clock")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        Task { await viewModel.refreshAllData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .refreshable {
            await viewModel.refreshCrashReports()
            await viewModel.refreshCrashStats()
        }
        .sheet(item: $selectedReport) { report in
            CrashDetailView(report: report, viewModel: viewModel)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: $settings, onSave: {})
        }
        .task {
            await viewModel.refreshCrashReports()
            await viewModel.refreshCrashStats()
        }
    }

    private var timeRangeSection: some View {
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
    }

    private var statsSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                CrashStatCard(
                    title: "总崩溃数",
                    value: "\(viewModel.crashStats?.totalCrashes ?? 0)",
                    subtitle: "\(viewModel.crashStats?.recentCrashes5min ?? 0) 个/5分钟",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
                CrashStatCard(
                    title: "自动重启",
                    value: "\(viewModel.crashStats?.autoRestarted ?? 0)",
                    subtitle: "成功恢复",
                    icon: "arrow.clockwise",
                    color: .cyan
                )
                CrashStatCard(
                    title: "最近崩溃",
                    value: viewModel.crashStats?.lastCrash ?? "无",
                    subtitle: "",
                    icon: "clock",
                    color: .orange
                )
                CrashStatCard(
                    title: "恢复率",
                    value: (viewModel.crashStats?.totalCrashes ?? 0) > 0 ?
                        String(format: "%.1f%%", Double(viewModel.crashStats?.autoRestarted ?? 0) / Double(viewModel.crashStats?.totalCrashes ?? 1) * 100) : "0%",
                    subtitle: "自动恢复率",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                )
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var typeDistributionSection: some View {
        if let stats = viewModel.crashStats, !stats.byType.isEmpty {
            Section("崩溃类型分布") {
                ForEach(Array(stats.byType.keys.sorted()), id: \.self) { type in
                    let count = stats.byType[type] ?? 0
                    CrashTypeBar(
                        type: type,
                        count: count,
                        total: stats.totalCrashes,
                        color: crashTypeColor(type)
                    )
                }
            }
        }
    }

    private var reportHeaderSection: some View {
        Section {
            HStack {
                Text("崩溃记录 (\(filteredReports.count))")
                    .font(.headline)
                Spacer()
                SearchBar(text: $searchText, placeholder: "搜索类型、消息、堆栈...")
            }
        }
    }

    @ViewBuilder
    private var reportListSection: some View {
        Section {
            if viewModel.crashReports.isEmpty && viewModel.isRefreshing {
                LoadingView()
            } else if let error = viewModel.refreshError {
                ErrorView(message: error, retryAction: {
                    Task { await viewModel.refreshCrashReports() }
                })
            } else if filteredReports.isEmpty {
                EmptyStateView()
            } else {
                ForEach(filteredReports) { report in
                    CrashReportRow(report: report) {
                        selectedReport = report
                    }
                }
            }
        }
    }
    
    private func crashTypeColor(_ type: String) -> Color {
        switch type {
        case "OutOfMemoryError", "OOMKilled": return .red
        case "Watchdog": return .orange
        case "PluginError", "ModError": return .purple
        case "StackOverflowError": return .orange
        case "WorldCorruption": return .red
        case "PermissionError": return .blue
        case "DiskFull": return .red
        case "JavaException": return .orange
        case "SIGTERM", "NormalExit": return .green
        default: return .gray
        }
    }
}

struct CrashStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct CrashTypeBar: View {
    let type: String
    let count: Int
    let total: Int
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    private var typeLabel: String {
        switch type {
        case "OutOfMemoryError": return "内存溢出 (OOM)"
        case "Watchdog": return "看门狗超时"
        case "PluginError": return "插件错误"
        case "ModError": return "模组错误"
        case "StackOverflowError": return "栈溢出"
        case "WorldCorruption": return "世界损坏"
        case "PermissionError": return "权限错误"
        case "DiskFull": return "磁盘已满"
        case "JavaException": return "Java异常"
        case "OOMKilled": return "系统OOM杀死"
        case "SIGTERM": return "正常停止信号"
        case "NormalExit": return "正常退出"
        default: return "未知类型"
        }
    }
    
    private var typeIcon: String {
        switch type {
        case "OutOfMemoryError", "OOMKilled": return "memorychip"
        case "Watchdog": return "timer"
        case "PluginError", "ModError": return "puzzlepiece.fill"
        case "StackOverflowError": return "cpu"
        case "WorldCorruption": return "exclamationmark.triangle.fill"
        case "PermissionError": return "lock.shield.fill"
        case "DiskFull": return "externaldrive.fill.badge.exclamationmark"
        case "JavaException": return "exclamationmark.circle.fill"
        case "SIGTERM", "NormalExit": return "checkmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: typeIcon)
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(typeLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * percentage, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

struct CrashReportRow: View {
    let report: CrashReport
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: report.crashTypeIcon)
                        .foregroundColor(report.crashTypeColor)
                        .frame(width: 24)
                    Text(report.crashTypeLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(report.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(report.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Label(report.serverUptimeStr, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: report.autoRestarted ? "arrow.clockwise" : "exclamationmark.triangle")
                            .font(.caption)
                        Text(report.autoRestarted ? "自动重启" : "需手动")
                            .font(.caption)
                    }
                    .foregroundColor(report.autoRestarted ? .cyan : .orange)
                    
                    if report.analyzed {
                        Label("已分析", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct CrashDetailView: View {
    let report: CrashReport
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: report.crashTypeIcon)
                                .foregroundColor(report.crashTypeColor)
                                .font(.title)
                            VStack(alignment: .leading) {
                                Text(report.crashTypeLabel)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(report.date.formatted(date: .complete, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Badge(text: "Exit: \(report.exitCode)", color: report.exitCode == 0 ? .green : .red)
                            Badge(text: report.autoRestarted ? "自动重启" : "需手动处理", color: report.autoRestarted ? .cyan : .orange)
                            Badge(text: report.analyzed ? "已分析" : "待分析", color: report.analyzed ? .green : .orange)
                        }
                    }
                    
                    // Sections
                    DetailSection(title: "错误信息", content: report.message)
                    DetailSection(title: "建议修复", content: report.suggestedFix.isEmpty ? "暂无建议" : report.suggestedFix, color: .cyan)
                    DetailSection(title: "堆栈跟踪", content: report.stackTrace.isEmpty ? "无堆栈信息" : report.stackTrace, font: .system(.caption, design: .monospaced))
                    DetailSection(title: "相关日志", content: report.relevantLogs, font: .system(.caption, design: .monospaced))
                    DetailSection(title: "JVM 参数", content: report.jvmArgs, font: .system(.caption, design: .monospaced))
                    
                    // Footer
                    VStack(alignment: .leading, spacing: 8) {
                        Label(report.serverUptimeStr, systemImage: "clock")
                        Label("重启次数: \(report.restartCount)", systemImage: "arrow.clockwise")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
                    Button(action: {
                        Task {
                            await viewModel.analyzeCrash(id: report.id)
                        }
                    }) {
                        Label(report.analyzed ? "已分析" : "标记分析", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(report.analyzed)
                }
                .padding()
            }
            .navigationTitle("崩溃详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

struct DetailSection: View {
    let title: String
    let content: String
    var color: Color = .primary
    var font: Font = .body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            ScrollView {
                Text(content)
                    .font(font)
                    .foregroundColor(color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 250)
            .padding()
            .background(Color(.tertiarySystemFill))
            .cornerRadius(10)
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text("加载失败")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重试", action: retryAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("暂无崩溃记录")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("该时间范围内服务器运行稳定 ✓")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
        }
        .padding(10)
        .background(Color(.tertiarySystemFill))
        .cornerRadius(10)
        .frame(maxWidth: 250)
    }
}