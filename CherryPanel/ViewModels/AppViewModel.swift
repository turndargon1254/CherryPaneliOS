import Foundation
import Combine
import SwiftUI

@MainActor
class AppViewModel: ObservableObject {
    static let shared = AppViewModel()
    
    // MARK: - Auth State
    @Published var isAuthenticated = false
    @Published var currentUser: String?
    @Published var userRole: String?
    @Published var isLoading = false
    @Published var authError: String?
    
    // MARK: - Server State
    @Published var serverStatus: ServerStatus?
    @Published var serverMetrics: ServerMetrics?
    @Published var statistics: StatisticsResponse?
    @Published var serverConfig: ConfigResponse.ServerConfig?
    
    // MARK: - Crash Data
    @Published var crashReports: [CrashReport] = []
    @Published var crashStats: CrashStats?
    @Published var selectedCrashReport: CrashReport?
    
    // MARK: - Files
    @Published var currentPath = ""
    @Published var files: [FileItem] = []
    @Published var fileContent: FileContentResponse?
    
    // MARK: - Console
    @Published var consoleLogs: [String] = []
    @Published var commandHistory: [String] = []
    @Published var isConsoleConnected = false
    
    // MARK: - Crash Reports
    @Published var crashReportsList: [CrashReport] = []
    @Published var crashStatsData: CrashStats?
    @Published var selectedCrash: CrashReport?
    
    // MARK: - Settings
    @Published var serverURL = ""
    @Published var apiKey = ""
    
    // MARK: - Loading States
    @Published var isRefreshing = false
    @Published var refreshError: String?
    
    private let api = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    private var logStreamTask: Task<Void, Never>?
    
    private init() {
        loadSavedSettings()
        checkAuthStatus()
    }
    
    // MARK: - Settings
    func loadSavedSettings() {
        serverURL = UserDefaults.standard.string(forKey: "server_url") ?? ""
        apiKey = UserDefaults.standard.string(forKey: "api_key") ?? ""
        api.baseURL = serverURL.isEmpty ? "http://localhost:22691" : serverURL
        api.apiKey = apiKey
    }
    
    func saveSettings() {
        UserDefaults.standard.set(serverURL, forKey: "server_url")
        UserDefaults.standard.set(apiKey, forKey: "api_key")
        api.baseURL = serverURL
        api.apiKey = apiKey
    }
    
    // MARK: - Authentication
    func checkAuthStatus() {
        isLoading = true
        Task {
            do {
                let response = try await api.checkSession()
                if response.authenticated {
                    isAuthenticated = true
                    currentUser = response.username
                    userRole = response.role
                    await refreshAllData()
                } else {
                    isAuthenticated = false
                }
            } catch {
                isAuthenticated = false
            }
            isLoading = false
        }
    }
    
    func login(username: String, password: String) async {
        isLoading = true
        authError = nil
        do {
            let response = try await api.login(username: username, password: password)
            if response.success {
                isAuthenticated = true
                currentUser = response.username
                userRole = response.role
                await refreshAllData()
            } else {
                authError = response.error ?? "登录失败"
            }
        } catch {
            authError = error.localizedDescription
        }
        isLoading = false
    }
    
    func logout() async {
        do {
            try await api.logout()
        } catch {
            print("Logout error: \(error)")
        }
        isAuthenticated = false
        currentUser = nil
        userRole = nil
        serverStatus = nil
        serverMetrics = nil
        statistics = nil
        crashReports = []
        crashStats = nil
        files = []
        consoleLogs = []
    }
    
    // MARK: - Data Refresh
    func refreshAllData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshServerStatus() }
            group.addTask { await self.refreshMetrics() }
            group.addTask { await self.refreshStatistics() }
            group.addTask { await self.refreshFiles() }
            group.addTask { await self.refreshCrashReports() }
            group.addTask { await self.refreshCrashStats() }
        }
    }
    
    func refreshServerStatus() async {
        do {
            serverStatus = try await api.getStatus()
        } catch {
            print("Failed to refresh status: \(error)")
        }
    }
    
    func refreshMetrics() async {
        do {
            serverMetrics = try await api.getMetrics()
        } catch {
            print("Failed to refresh metrics: \(error)")
        }
    }
    
    func refreshStatistics() async {
        do {
            statistics = try await api.getStatistics()
        } catch {
            print("Failed to refresh statistics: \(error)")
        }
    }
    
    func refreshFiles() async {
        do {
            files = try await api.listFiles(path: currentPath)
        } catch {
            print("Failed to refresh files: \(error)")
        }
    }
    
    func refreshCrashReports() async {
        do {
            crashReports = try await api.getCrashReports(hours: 24, limit: 100)
        } catch {
            print("Failed to refresh crash reports: \(error)")
        }
    }
    
    func refreshCrashStats() async {
        do {
            crashStats = try await api.getCrashStats(hours: 24)
        } catch {
            print("Failed to refresh crash stats: \(error)")
        }
    }
    
    // MARK: - Server Control
    func startServer() async -> Bool {
        do {
            let response = try await api.startServer()
            if response.success {
                await refreshServerStatus()
                return true
            }
            return false
        } catch {
            return false
        }
    }
    
    func stopServer() async -> Bool {
        do {
            let response = try await api.stopServer()
            if response.success {
                await refreshServerStatus()
                return true
            }
            return false
        } catch {
            return false
        }
    }
    
    func restartServer() async -> Bool {
        do {
            let response = try await api.restartServer()
            if response.success {
                await refreshServerStatus()
                return true
            }
            return false
        } catch {
            return false
        }
    }
    
    // MARK: - Console
    func sendCommand(_ command: String) async -> String? {
        do {
            let response = try await api.sendRconCommand(command)
            if response.success {
                commandHistory.insert(command, at: 0)
                if commandHistory.count > 100 { commandHistory.removeLast() }
                return response.output
            }
            return nil
        } catch {
            return nil
        }
    }
    
    func startLogStream() {
        logStreamTask?.cancel()
        logStreamTask = Task {
            do {
                isConsoleConnected = true
                for try await line in api.streamLogs() {
                    await MainActor.run {
                        consoleLogs.append(line)
                        if consoleLogs.count > 1000 { consoleLogs.removeFirst() }
                    }
                }
            } catch {
                await MainActor.run {
                    isConsoleConnected = false
                }
            }
        }
    }
    
    func stopLogStream() {
        logStreamTask?.cancel()
        logStreamTask = nil
        isConsoleConnected = false
    }
    
    func clearLogs() {
        consoleLogs.removeAll()
    }
    
    // MARK: - Files
    func navigateTo(path: String) {
        currentPath = path
        Task { await refreshFiles() }
    }
    
    func goUp() {
        if !currentPath.isEmpty {
            let parts = currentPath.split(separator: "/")
            currentPath = parts.dropLast().joined(separator: "/")
            Task { await refreshFiles() }
        }
    }
    
    func loadFileContent(path: String) async {
        do {
            fileContent = try await api.getFileContent(path: path)
        } catch {
            print("Failed to load file content: \(error)")
        }
    }
    
    // MARK: - Crash Reports
    func loadCrashReports(hours: Int = 24) async {
        do {
            crashReports = try await api.getCrashReports(hours: hours, limit: 100)
        } catch {
            print("Failed to load crash reports: \(error)")
        }
    }
    
    func analyzeCrash(id: Int) async -> Bool {
        do {
            try await api.analyzeCrash(id: id)
            await refreshCrashReports()
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Auto Refresh Timer
    func startAutoRefresh(interval: TimeInterval = 30) {
        Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.refreshServerStatus() }
            }
            .store(in(&cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        logStreamTask?.cancel()
        cancellables.removeAll()
    }
}