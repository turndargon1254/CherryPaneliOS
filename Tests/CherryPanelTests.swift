import XCTest
@testable import CherryPanel

final class CherryPanelTests: XCTestCase {
    func testServerStatusDecoding() throws {
        let json = """
        {"running":true,"pid":1234,"start_time":"2026-08-28T12:00:00","uptime":"1h 2m 3s","uptime_seconds":3723}
        """
        let data = json.data(using: .utf8)!
        let status = try JSONDecoder().decode(ServerStatus.self, from: data)
        XCTAssertTrue(status.running)
        XCTAssertEqual(status.pid, 1234)
    }

    func testServerMetricsDecoding() throws {
        let json = """
        {"tps":19.8,"mspt":2.5,"cpu_percent":35.2,"memory_used_mb":9000,"memory_max_mb":16384,
         "memory_percent":54.9,"jvm_heap_used_mb":9000,"jvm_heap_max_mb":16384,"jvm_heap_percent":54.9,
         "disk_free_gb":97,"disk_total_gb":116,"disk_percent":16.4,
         "players_online":2,"players_max":20,"players_list":["Alice","Bob"],"timestamp":"2026-08-28T12:00:00"}
        """
        let data = json.data(using: .utf8)!
        let metrics = try JSONDecoder().decode(ServerMetrics.self, from: data)
        XCTAssertEqual(metrics.playersOnline, 2)
        XCTAssertEqual(metrics.playersList?.count, 2)
    }
}
