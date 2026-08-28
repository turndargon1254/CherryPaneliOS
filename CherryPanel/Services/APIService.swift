import Foundation
import Combine

class APIService: ObservableObject {
    static let shared = APIService()
    
    @Published var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "api_base_url")
        }
    }
    
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "api_key")
        }
    }
    
    private var session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.baseURL = UserDefaults.standard.string(forKey: "api_base_url") ?? "http://localhost:22691"
        self.apiKey = UserDefaults.standard.string(forKey: "api_key") ?? ""
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Request Builder
    private func buildRequest(path: String, method: String = "GET", body: Data? = nil) -> URLRequest? {
        guard let url = URL(string: baseURL + path) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        // Cookie handling for session-based auth
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeader {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        return request
    }
    
    // MARK: - Generic Request
    private func performRequest<T: Decodable>(_ request: URLRequest, type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Save cookies
        if let url = request.url,
           let headers = httpResponse.allHeaderFields as? [String: String],
           let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url) {
            HTTPCookieStorage.shared.setCookies(cookies, for: url, mainDocumentURL: nil)
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        default:
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMsg)
        }
    }
    
    // MARK: - Auth
    func login(username: String, password: String) async throws -> LoginResponse {
        let body = try JSONEncoder().encode(LoginRequest(username: username, password: password))
        guard let request = buildRequest(path: "/api/login", method: "POST", body: body) else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, type: LoginResponse.self)
    }
    
    func logout() async throws {
        guard let request = buildRequest(path: "/api/logout", method: "POST") else {
            throw APIError.invalidURL
        }
        _ = try await performRequest(request, type: APIResponse<EmptyResponse>.self)
    }
    
    func checkSession() async throws -> CheckSessionResponse {
        guard let request = buildRequest(path: "/api/check_session") else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, type: CheckSessionResponse.self)
    }
    
    // MARK: - Server Control
    func getStatus() async throws -> ServerStatus {
        guard let request = buildRequest(path: "/api/status") else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, type: ServerStatus.self)
    }
    
    func startServer() async throws -> APIResponse<EmptyResponse> {
        guard let request = buildRequest(path: "/api/start", method: "POST") else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, type: APIResponse<EmptyResponse>.self)
    }
    
    func stopServer() async throws -> APIResponse<EmptyResponse> {
        guard let request = buildRequest(path: "/api/stop", method: "POST") else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, type: APIResponse<EmptyResponse>.self)
    }
    
    func restartServer() async throws -> APIResponse<EmptyResponse> {
        guard let request = buildRequest(path: "/api/restart", method: "POST") else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, type: APIResponse<EmptyResponse>.self)
    }
    
    func sendCommand(_ command: String) async throws -> APIResponse<EmptyResponse> {
        let body = try JSONEncoder().encode(["command": command])
        guard let request = buildRequest(path: "/api/command", method: "POST", body: body) else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, type: APIResponse<EmptyResponse>.self)
    }

    func sendRconCommand(_ command: String) async throws -> RCONCommandResponse {
        let body = try JSONEncoder().encode(["command": command])
        guard let request = buildRequest(path: "/api/rcon/command", method: "POST", body: body) else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, type: RCONCommandResponse.self)
    }

    func getCommandHistory() async throws -> [String] {
        guard let request = buildRequest(path: "/api/command_history") else {
            throw APIError.invalidURL
        }
        let response = try await performRequest(request, type: CommandHistoryResponse.self)
        return response.history
    }
    
    // MARK: - Metrics
    func getMetrics() async throws -> ServerMetrics {
        guard let request = buildRequest(path: "/api/metrics") else {
            throw APIError.invalidURL
        }
        let response = try await performRequest(request, type: MetricsResponse.self)
        return response.metrics
    }
    
    func getStatistics() async throws -> StatisticsResponse {
        guard let request = buildRequest(path: "/api/statistics") else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, type: StatisticsResponse.self)
    }
    
    // MARK: - Crash Reports
    func getCrashReports(hours: Int = 24, limit: Int = 100) async throws -> [CrashReport] {
        let path = "/api/crash/reports?hours=\(hours)&limit=\(limit)"
        guard let request = buildRequest(path: path) else {
            throw APIError.invalidURL
        }
        let response = try await performRequest(request, type: CrashReportsResponse.self)
        return response.data
    }
    
    func getCrashReport(id: Int) async throws -> CrashReport {
        guard let request = buildRequest(path: "/api/crash/reports/\(id)") else {
            throw APIError.invalidURL
        }
        let response = try await performRequest(request, type: APIResponse<CrashReport>.self)
        return response.data!
    }
    
    func getCrashStats(hours: Int = 24) async throws -> CrashStats {
        guard let request = buildRequest(path: "/api/crash/stats?hours=\(hours)") else {
            throw APIError.invalidURL
        }
        let response = try await performRequest(request, type: CrashStatsResponse.self)
        return response.data
    }
    
    func analyzeCrash(id: Int) async throws {
        guard let request = buildRequest(path: "/api/crash/reports/\(id)/analyze", method: "POST") else {
            throw APIError.invalidURL
        }
        _ = try await performRequest(request, type: APIResponse<EmptyResponse>.self)
    }
    
    func getCrashAnalysisHistory(reportId: Int) async throws -> [AIAnalysisHistory] {
        guard let request = buildRequest(path: "/api/crash/reports/\(reportId)/analysis_history") else {
            throw APIError.invalidURL
        }
        let response = try await performRequest(request, type: CrashAnalysisHistoryResponse.self)
        return response.data
    }
    
    func getAIAnalysisHistory(hours: Int = 24, limit: Int = 100) async throws -> [AIAnalysisHistory] {
        let path = "/api/crash/analysis_history?hours=\(hours)&limit=\(limit)"
        guard let request = buildRequest(path: path) else {
            throw APIError.invalidURL
        }
        let response = try await performRequest(request, type: AIAnalysisHistoryResponse.self)
        return response.data
    }
    
    func getAIAnalysisStats(hours: Int = 24) async throws -> AIAnalysisStats {
        guard let request = buildRequest(path: "/api/crash/analysis_stats?hours=\(hours)") else {
            throw APIError.invalidURL
        }
        let response = try await performRequest(request, type: AIAnalysisStatsResponse.self)
        return response.data
    }
    
    func refreshProxies() async throws -> APIResponse<ProxyRefreshResponse> {
        guard let request = buildRequest(path: "/api/crash/proxy/refresh", method: "POST") else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, type: APIResponse<ProxyRefreshResponse>.self)
    }
    
    // MARK: - Files
    func listFiles(path: String = "") async throws -> [FileItem] {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let pathQuery = path.isEmpty ? "" : "?path=\(encodedPath)"
        guard let request = buildRequest(path: "/api/files\(pathQuery)") else {
            throw APIError.invalidURL
        }
        let response = try await performRequest(request, type: FileListResponse.self)
        return response.files
    }
    
    func getFileContent(path: String) async throws -> FileContentResponse {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let request = buildRequest(path: "/api/files/content?path=\(encodedPath)") else {
            throw APIError.invalidURL
        }
        return try await performRequest(request, type: FileContentResponse.self)
    }
    
    // MARK: - Config
    func getConfig() async throws -> ConfigResponse.ServerConfig {
        guard let request = buildRequest(path: "/api/config") else {
            throw APIError.invalidURL
        }
        let response = try await performRequest(request, type: ConfigResponse.self)
        return response.config
    }
    
    // MARK: - Logs (SSE)
    func streamLogs() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard let url = URL(string: baseURL + "/api/logs") else {
                continuation.finish(throwing: APIError.invalidURL)
                return
            }
            
            var request = URLRequest(url: url)
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }
                
                guard let data = data,
                      let string = String(data: data, encoding: .utf8) else {
                    return
                }
                
                let lines = string.components(separatedBy: "\n\n")
                for line in lines {
                    if line.hasPrefix("data: ") {
                        let jsonString = String(line.dropFirst(6))
                        if let data = jsonString.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let type = json["type"] as? String,
                           type == "live" || type == "history",
                           let content = json["content"] as? String {
                            continuation.yield(content)
                        }
                    }
                }
            }
            
            task.resume()
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Supporting Types
struct EmptyResponse: Codable {}

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

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case unauthorized
    case forbidden
    case serverError(Int, String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的服务器地址"
        case .invalidResponse: return "服务器响应无效"
        case .decodingError(let e): return "数据解析失败: \(e.localizedDescription)"
        case .unauthorized: return "登录已过期，请重新登录"
        case .forbidden: return "权限不足"
        case .serverError(let code, let msg): return "服务器错误 (\(code)): \(msg)"
        case .networkError(let e): return "网络错误: \(e.localizedDescription)"
        }
    }
}

// MARK: - Response Types for New Endpoints

struct AIAnalysisHistory: Codable {
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

struct CrashReportsResponse: Codable {
    let success: Bool
    let data: [CrashReport]
    let count: Int
}

struct CrashReportResponse: Codable {
    let success: Bool
    let data: CrashReport
}

struct CrashStatsResponse: Codable {
    let success: Bool
    let data: CrashStats
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

struct RCONCommandResponse: Codable {
    let success: Bool
    let output: String?
    let message: String?
}

struct MetricsResponse: Codable {
    let success: Bool
    let metrics: ServerMetrics
}