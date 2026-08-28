import WidgetKit
import SwiftUI

struct ServerStatusWidget: Widget {
    let kind: String = "ServerStatusWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ServerStatusProvider()) { entry in
            ServerStatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Minecraft 服务器")
        .description("显示服务器状态、玩家数和 TPS")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular])
    }
}

struct ServerStatusEntry: TimelineEntry, Codable {
    let date: Date
    let status: String
    let players: String
    let tps: String
    let isOnline: Bool
}

struct ServerStatusProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.cherrypanel.app")

    func placeholder(in context: Context) -> ServerStatusEntry {
        ServerStatusEntry(date: Date(), status: "运行中", players: "5/20", tps: "19.8", isOnline: true)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ServerStatusEntry) -> Void) {
        if let cached = loadCachedEntry() {
            completion(cached)
        } else {
            completion(placeholder(in: context))
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ServerStatusEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300))) // 5 分钟
            completion(timeline)
        }
    }

    // 使用 Widget 内置 URLSession 直接请求，避免依赖主 App 的 APIService
    private func fetchEntry() async -> ServerStatusEntry {
        let baseURL = defaults?.string(forKey: "api_base_url") ?? "http://localhost:22691"
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.httpCookieStorage = HTTPCookieStorage.shared
        let session = URLSession(configuration: config)

        var status = WidgetServerStatus(running: false, pid: nil, start_time: nil, uptime: "--", uptime_seconds: 0)
        var metrics = WidgetServerMetrics(tps: 0, mspt: 0, players_online: 0, players_max: 0)

        // 请求状态
        if let url = URL(string: baseURL + "/api/status"),
           let (data, _) = try? await session.data(from: url),
           let decoded = try? JSONDecoder().decode(WidgetServerStatus.self, from: data) {
            status = decoded
        }

        // 请求指标
        if let url = URL(string: baseURL + "/api/metrics") {
            struct MetricsWrapper: Decodable {
                let metrics: WidgetServerMetrics
            }
            if let (data, _) = try? await session.data(from: url),
               let wrapper = try? JSONDecoder().decode(MetricsWrapper.self, from: data) {
                metrics = wrapper.metrics
            }
        }

        let entry = ServerStatusEntry(
            date: Date(),
            status: status.running ? "运行中" : "离线",
            players: "\(metrics.players_online)/\(metrics.players_max)",
            tps: String(format: "%.1f", metrics.tps),
            isOnline: status.running
        )
        saveEntry(entry)
        return entry
    }
    
    private func saveEntry(_ entry: ServerStatusEntry) {
        let data = try? JSONEncoder().encode(entry)
        defaults?.set(data, forKey: "widget_entry")
    }
    
    private func loadCachedEntry() -> ServerStatusEntry? {
        guard let data = defaults?.data(forKey: "widget_entry"),
              let entry = try? JSONDecoder().decode(ServerStatusEntry.self, from: data) else {
            return nil
        }
        return entry
    }
}

struct ServerStatusWidgetEntryView: View {
    var entry: ServerStatusProvider.Entry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        @unknown default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: ServerStatusEntry
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(entry.isOnline ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text("MC 服务器")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.status)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(entry.isOnline ? .green : .red)
                    Spacer()
                }
                HStack {
                    Label(entry.players, systemImage: "person.2.fill")
                        .font(.caption)
                    Spacer()
                }
                HStack {
                    Label(entry.tps, systemImage: "speedometer")
                        .font(.caption)
                    Spacer()
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct MediumWidgetView: View {
    let entry: ServerStatusEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(entry.isOnline ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text("Minecraft 服务器")
                        .font(.headline)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Label(entry.status, systemImage: "circle.fill")
                        .foregroundColor(entry.isOnline ? .green : .red)
                    Label(entry.players, systemImage: "person.2.fill")
                    Label(entry.tps, systemImage: "speedometer")
                }
            }
            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct LargeWidgetView: View {
    let entry: ServerStatusEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Circle()
                    .fill(entry.isOnline ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text("Minecraft 服务器")
                    .font(.title2)
                    .bold()
                Spacer()
            }
            
            Divider()
            
            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("状态")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Label(entry.status, systemImage: "circle.fill")
                        .foregroundColor(entry.isOnline ? .green : .red)
                        .font(.headline)
                }
                VStack(alignment: .leading) {
                    Text("玩家")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.players)
                        .font(.headline)
                }
                VStack(alignment: .leading) {
                    Text("TPS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.tps)
                        .font(.headline)
                }
            }
            
            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct AccessoryRectangularView: View {
    let entry: ServerStatusEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(entry.isOnline ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text("MC 服务器")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Label(entry.status, systemImage: "circle.fill")
                    .foregroundColor(entry.isOnline ? .green : .red)
                Label(entry.players, systemImage: "person.2.fill")
                Label(entry.tps, systemImage: "speedometer")
            }
            .font(.caption)
        }
    }
}

struct AccessoryCircularView: View {
    let entry: ServerStatusEntry
    
    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(entry.isOnline ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(entry.tps)
                .font(.caption2)
                .fontWeight(.bold)
            Text("TPS")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}