import SwiftUI

struct ConsoleView: View {
    @StateObject private var viewModel = AppViewModel.shared
    @State private var command = ""
    @State private var searchText = ""
    @State private var isPaused = false
    @State private var showSearch = false
    
    var filteredLogs: [String] {
        if searchText.isEmpty {
            return viewModel.consoleLogs
        }
        return viewModel.consoleLogs.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("服务器控制台", systemImage: "terminal")
                    .font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    Circle()
                        .fill(viewModel.isConsoleConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.isConsoleConnected ? "已连接" : "断开")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(filteredLogs.count) 行")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if isPaused {
                        Label("已暂停", systemImage: "pause.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
            
            // Toolbar
            HStack {
                Button(action: { viewModel.clearLogs() }) {
                    Label("清空", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                
                Button(action: { isPaused.toggle() }) {
                    Label(isPaused ? "继续" : "暂停", systemImage: isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: { showSearch.toggle() }) {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                
                Button(action: { Task { await viewModel.refreshAllData() } }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
            
            // Search Bar
            if showSearch {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索日志...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Button(action: { showSearch = false; searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Log Output
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(filteredLogs.enumerated()), id: \.offset) { index, log in
                        Text(log)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .id(index)
                    }
                }
                .onChange(of: filteredLogs.count) { _ in
                    if !isPaused, let last = filteredLogs.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            .listStyle(.plain)
            
            // Command Bar
            HStack(spacing: 8) {
                TextField(viewModel.isConsoleConnected ? "输入控制台命令..." : "服务器离线", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!viewModel.isConsoleConnected)
                    .onSubmit { sendCommand() }
                
                Button("发送") {
                    sendCommand()
                }
                .buttonStyle(.borderedProminent)
                .disabled(command.trimmingCharacters(in: .whitespaces).isEmpty || !viewModel.isConsoleConnected)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("控制台")
        .onAppear {
            viewModel.startLogStream()
        }
        .onDisappear {
            viewModel.stopLogStream()
        }
    }
    
    private func sendCommand() {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task {
            let output = await viewModel.sendCommand(trimmed)
            // 显示命令和 RCON 输出
            viewModel.consoleLogs.append("> \(trimmed)")
            if let output = output, !output.isEmpty {
                viewModel.consoleLogs.append(output)
            }
            if viewModel.consoleLogs.count > 1000 { viewModel.consoleLogs.removeFirst() }
            command = ""
        }
    }
}