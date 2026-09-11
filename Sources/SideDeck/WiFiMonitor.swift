import Combine
@preconcurrency import CoreLocation
import CoreWLAN
import Foundation

struct WiFiReading: Equatable {
    let isPowered: Bool
    let ssid: String?
    let rssi: Int
}

enum WiFiAuthorization: Equatable {
    case notDetermined
    case allowed
    case denied
}

struct WiFiSnapshot: Equatable {
    let name: String
    let detail: String
    let isPowered: Bool
    let isConnected: Bool
    let rssi: Int

    static let loading = WiFiSnapshot(
        name: "Wi‑Fi",
        detail: "Checking network…",
        isPowered: true,
        isConnected: false,
        rssi: -100
    )
}

protocol WiFiReadingProviding {
    func read() -> WiFiReading
}

struct SystemWiFiReader: WiFiReadingProviding {
    func read() -> WiFiReading {
        guard let interface = CWWiFiClient.shared().interface() else {
            return WiFiReading(isPowered: false, ssid: nil, rssi: -100)
        }
        return WiFiReading(
            isPowered: interface.powerOn(),
            ssid: interface.ssid()?.trimmingCharacters(in: .whitespacesAndNewlines),
            rssi: interface.rssiValue()
        )
    }
}

@MainActor
final class WiFiMonitor: NSObject, ObservableObject {
    @Published private(set) var snapshot: WiFiSnapshot = .loading

    private let reader: WiFiReadingProviding
    private let locationManager: CLLocationManager

    init(
        reader: WiFiReadingProviding = SystemWiFiReader(),
        locationManager: CLLocationManager = CLLocationManager()
    ) {
        self.reader = reader
        self.locationManager = locationManager
        super.init()
        self.locationManager.delegate = self
    }

    func start() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        refresh()
    }

    func refresh() {
        snapshot = Self.resolve(
            reading: reader.read(),
            authorization: Self.authorization(from: locationManager.authorizationStatus)
        )
    }

    nonisolated static func resolve(
        reading: WiFiReading,
        authorization: WiFiAuthorization
    ) -> WiFiSnapshot {
        guard reading.isPowered else {
            return WiFiSnapshot(
                name: "Wi‑Fi Off",
                detail: "Wireless networking is disabled",
                isPowered: false,
                isConnected: false,
                rssi: reading.rssi
            )
        }

        if let ssid = reading.ssid, !ssid.isEmpty {
            let quality: String
            if reading.rssi >= -55 { quality = "Strong signal" }
            else if reading.rssi >= -70 { quality = "Good signal" }
            else { quality = "Weak signal" }
            return WiFiSnapshot(
                name: ssid,
                detail: "\(quality) · \(reading.rssi) dBm",
                isPowered: true,
                isConnected: true,
                rssi: reading.rssi
            )
        }

        switch authorization {
        case .notDetermined:
            return WiFiSnapshot(name: "Network name unavailable", detail: "Waiting for Location permission", isPowered: true, isConnected: false, rssi: reading.rssi)
        case .denied:
            return WiFiSnapshot(name: "Network name hidden", detail: "Allow Location in System Settings", isPowered: true, isConnected: false, rssi: reading.rssi)
        case .allowed:
            return WiFiSnapshot(name: "Not connected", detail: "Wi‑Fi is on", isPowered: true, isConnected: false, rssi: reading.rssi)
        }
    }

    nonisolated private static func authorization(from status: CLAuthorizationStatus) -> WiFiAuthorization {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: return .allowed
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }
}

extension WiFiMonitor: @MainActor CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refresh()
    }
}
