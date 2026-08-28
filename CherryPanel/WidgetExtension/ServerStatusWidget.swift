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

struct ServerStatusEntry: TimelineEntry {
    let date: Date
    let status: String
    let players: String
    let tps: String
    let isOnline: Bool
}

struct ServerStatusProvider: TimelineProvider {
    let apiService = APIService.shared
    
    func placeholder(in context: Context) -> ServerStatusEntry {
        ServerStatusEntry(date: Date(), status: "运行中", players: "5/20", tps: "19.8", isOnline: true)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ServerStatusEntry) -> Void) {
        // Try to get cached data
        if let cached = loadCachedEntry() {
            completion(cached)
        } else {
            completion(placeholder(in: context))
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ServerStatusEntry>) -> Void) {
        Task {
            do {
                let status = try await APIService.shared.getStatus()
                let metrics = try await APIService.shared.getMetrics()
                
                let entry = ServerStatusEntry(
                    date: Date(),
                    status: status.running ? "运行中" : "离线",
                    players: "\(metrics.playersOnline)/\(metrics.playersMax)",
                    tps: String(format: "%.1f", metrics.tps),
                    isOnline: status.running
                )
                
                // Save to shared cache
                saveEntry(entry)
                
                let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300))) // 5 minutes
                completion(timeline)
            } catch {
                // Use cached or placeholder on error
                let entry = loadCachedEntry() ?? placeholder(in: Context())
                let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
                completion(timeline)
            }
        }
    }
    
    private func saveEntry(_ entry: ServerStatusEntry) {
        let data = try? JSONEncoder().encode(entry)
        UserDefaults(suiteName: "group.com.cherrypanel.app")?.set(data, forKey: "widget_entry")
    }
    
    private func loadCachedEntry() -> ServerStatusEntry? {
        guard let data = UserDefaults(suiteName: "group.com.cherrypanel.app")?.data(forKey: "widget_entry"),
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