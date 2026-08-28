import Foundation

// Widget 专用的最小化数据模型（独立于主 App，避免 target 依赖问题）

struct WidgetServerStatus: Decodable {
    let running: Bool
    let pid: Int?
    let start_time: String?
    let uptime: String
    let uptime_seconds: Int
}

struct WidgetServerMetrics: Decodable {
    let tps: Double
    let mspt: Double
    let players_online: Int
    let players_max: Int

    enum CodingKeys: String, CodingKey {
        case tps, mspt
        case players_online = "players_online"
        case players_max = "players_max"
    }
}
