import Foundation

// MARK: - Server Status
struct ServerStatus: Codable {
    let running: Bool
    let pid: Int?
    let startTime: String?
    let uptime: String
    let uptimeSeconds: Int
    
    enum CodingKeys: String, CodingKey {
        case running, pid, uptime
        case startTime = "start_time"
        case uptimeSeconds = "uptime_seconds"
    }
}

// MARK: - Server Metrics
struct ServerMetrics: Codable {
    let tps: Double
    let mspt: Double
    let cpuPercent: Double
    let memoryUsedMB: Double
    let memoryMaxMB: Double
    let memoryPercent: Double
    let jvmHeapUsedMB: Double
    let jvmHeapMaxMB: Double
    let jvmHeapPercent: Double
    let diskFreeGB: Double
    let diskTotalGB: Double
    let diskPercent: Double
    let playersOnline: Int
    let playersMax: Int
    let playersList: [String]?
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case tps, mspt
        case cpuPercent = "cpu_percent"
        case memoryUsedMB = "memory_used_mb"
        case memoryMaxMB = "memory_max_mb"
        case memoryPercent = "memory_percent"
        case jvmHeapUsedMB = "jvm_heap_used_mb"
        case jvmHeapMaxMB = "jvm_heap_max_mb"
        case jvmHeapPercent = "jvm_heap_percent"
        case diskFreeGB = "disk_free_gb"
        case diskTotalGB = "disk_total_gb"
        case diskPercent = "disk_percent"
        case playersOnline = "players_online"
        case playersMax = "players_max"
        case playersList = "players_list"
        case timestamp
    }
}

// MARK: - Statistics Response
struct StatisticsResponse: Codable {
    let success: Bool
    let status: ServerStatus
    let metrics: ServerMetrics
    let serverDir: String
    let jarFile: String
    
    enum CodingKeys: String, CodingKey {
        case success, status, metrics
        case serverDir = "server_dir"
        case jarFile = "jar_file"
    }
}

// MARK: - File Models
struct FileItem: Codable, Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDir: Bool
    let size: Int
    let sizeStr: String
    let modified: String?
    
    enum CodingKeys: String, CodingKey {
        case name, path, size, modified
        case isDir = "is_dir"
        case sizeStr = "size_str"
    }
    
    var iconName: String {
        if isDir { return "folder.fill" }
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "jar": return "shippingbox.fill"
        case "json", "yml", "yaml": return "doc.text.fill"
        case "txt", "log": return "doc.fill"
        case "png", "jpg", "jpeg", "gif", "webp": return "photo.fill"
        case "mp3", "wav", "ogg": return "music.note"
        case "mp4", "mov", "mkv": return "film.fill"
        default: return "doc.fill"
        }
    }
}

struct FileListResponse: Codable {
    let success: Bool
    let files: [FileItem]
    let currentPath: String
    
    enum CodingKeys: String, CodingKey {
        case success, files
        case currentPath = "current_path"
    }
}

struct FileContentResponse: Codable {
    let success: Bool
    let path: String
    let content: String
    let encoding: String
    let size: Int
}

// MARK: - Crash Models
struct CrashReport: Codable, Identifiable {
    let id: Int
    let timestamp: String
    let exitCode: Int
    let crashType: String
    let message: String
    let stackTrace: String
    let relevantLogs: String
    let jvmArgs: String
    let serverUptimeSeconds: Int
    let serverUptimeStr: String
    let restartCount: Int
    let autoRestarted: Bool
    let analyzed: Bool
    let analysisResult: String
    let suggestedFix: String
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, message
        case exitCode = "exit_code"
        case crashType = "crash_type"
        case stackTrace = "stack_trace"
        case relevantLogs = "relevant_logs"
        case jvmArgs = "jvm_args"
        case serverUptimeSeconds = "server_uptime_seconds"
        case serverUptimeStr = "server_uptime_str"
        case restartCount = "restart_count"
        case autoRestarted = "auto_restarted"
        case analyzed
        case analysisResult = "analysis_result"
        case suggestedFix = "suggested_fix"
    }
    
    var date: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: timestamp) ?? Date()
    }
    
    var crashTypeLabel: String {
        switch crashType {
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
    
    var crashTypeIcon: String {
        switch crashType {
        case "OutOfMemoryError", "OOMKilled": return "memorychip"
        case "Watchdog": return "timer"
        case "PluginError", "ModError": return "puzzlepiece.fill"
        case "StackOverflowError": return "cpu"
        case "WorldCorruption": return "exclamationmark.triangle.fill"
        case "PermissionError": return "lock.shield.fill"
        case "DiskFull": return "externaldrive.fill.badge.exclamationmark"
        case "JavaException": return "exclamationmark.circle.fill"
        case "OOMKilled": return "memorychip"
        case "SIGTERM", "NormalExit": return "checkmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    var crashTypeColor: Color {
        switch crashType {
        case "OutOfMemoryError", "OOMKilled", "WorldCorruption", "DiskFull": return .red
        case "Watchdog": return .orange
        case "PluginError", "ModError", "JavaException": return .purple
        case "StackOverflowError": return .orange
        case "PermissionError": return .blue
        case "SIGTERM", "NormalExit": return .green
        default: return .gray
        }
    }
}

struct CrashStats: Codable {
    let totalCrashes: Int
    let autoRestarted: Int
    let byType: [String: Int]
    let recentCrashes5min: Int
    let lastCrash: String?
    
    enum CodingKeys: String, CodingKey {
        case totalCrashes = "total_crashes"
        case autoRestarted = "auto_restarted"
        case byType = "by_type"
        case recentCrashes5min = "recent_crashes_5min"
        case lastCrash = "last_crash"
    }
}

struct CrashReportsResponse: Codable {
    let success: Bool
    let data: [CrashReport]
    let count: Int
}

struct CrashStatsResponse: Codable {
    let success: Bool
    let data: CrashStats
}

// MARK: - Auth Models
struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct LoginResponse: Codable {
    let success: Bool
    let username: String?
    let role: String?
    let error: String?
}

struct CheckSessionResponse: Codable {
    let authenticated: Bool
    let username: String?
    let role: String?
}

// MARK: - Generic API Response
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
    let count: Int?
}

// MARK: - Command History
struct CommandHistoryResponse: Codable {
    let success: Bool
    let history: [String]
}

// MARK: - Config Response
struct ConfigResponse: Codable {
    let success: Bool
    let config: ServerConfig
    
    struct ServerConfig: Codable {
        let mcServerDir: String
        let jarFile: String
        let javaOpts: String
        let logFile: String
        
        enum CodingKeys: String, CodingKey {
            case mcServerDir = "MC_SERVER_DIR"
            case jarFile = "JAR_FILE"
            case javaOpts = "JAVA_OPTS"
            case logFile = "LOG_FILE"
        }
    }
}

// MARK: - Color Extension
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - AI Analysis Models
struct AIAnalysisHistory: Codable, Identifiable {
    let id: Int
    let timestamp: String
    let crashReportId: Int?
    let provider: String
    let model: String
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let success: Int
    let errorMessage: String?
    let analysisResult: String
    let suggestedFix: String
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, provider, model, success
        case crashReportId = "crash_report_id"
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case errorMessage = "error_message"
        case analysisResult = "analysis_result"
        case suggestedFix = "suggested_fix"
    }
}

struct AIAnalysisStats: Codable {
    let byProvider: [AIProviderStats]
    let summary: AIStatsSummary
}

struct AIProviderStats: Codable {
    let provider: String
    let total: Int
    let successCount: Int
    let totalPromptTokens: Int
    let totalCompletionTokens: Int
}

struct AIStatsSummary: Codable {
    let total: Int
    let avgTokens: Double
}

struct CrashAnalysisHistoryResponse: Codable {
    let success: Bool
    let data: [AIAnalysisHistory]
    let count: Int
}

struct AIAnalysisHistoryResponse: Codable {
    let success: Bool
    let data: [AIAnalysisHistory]
    let count: Int
}

struct AIAnalysisStatsResponse: Codable {
    let success: Bool
    let data: AIAnalysisStats
}

struct ProxyRefreshResponse: Codable {
    let message: String
}