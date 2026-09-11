import XCTest
@testable import SideDeck

final class WiFiMonitorTests: XCTestCase {
    func testConnectedNetworkUsesActualSSID() {
        let snapshot = WiFiMonitor.resolve(
            reading: WiFiReading(isPowered: true, ssid: "Studio 5G", rssi: -48),
            authorization: .allowed
        )

        XCTAssertEqual(snapshot.name, "Studio 5G")
        XCTAssertEqual(snapshot.detail, "Strong signal · -48 dBm")
        XCTAssertTrue(snapshot.isConnected)
    }

    func testMissingPermissionExplainsWhyNameIsUnavailable() {
        let snapshot = WiFiMonitor.resolve(
            reading: WiFiReading(isPowered: true, ssid: nil, rssi: -62),
            authorization: .denied
        )

        XCTAssertEqual(snapshot.name, "Network name hidden")
        XCTAssertEqual(snapshot.detail, "Allow Location in System Settings")
        XCTAssertFalse(snapshot.isConnected)
    }

    func testPoweredOffStateIsNeverReportedAsConnected() {
        let snapshot = WiFiMonitor.resolve(
            reading: WiFiReading(isPowered: false, ssid: "Stale Name", rssi: -90),
            authorization: .allowed
        )

        XCTAssertEqual(snapshot.name, "Wi‑Fi Off")
        XCTAssertEqual(snapshot.detail, "Wireless networking is disabled")
        XCTAssertFalse(snapshot.isConnected)
    }
}
