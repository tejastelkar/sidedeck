import Combine
import SwiftUI

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    func resolved(system: ColorScheme) -> ColorScheme {
        switch self {
        case .system: return system
        case .dark: return .dark
        case .light: return .light
        }
    }
}

enum AccentChoice: String, Codable, CaseIterable, Identifiable {
    case system
    case blue
    case indigo
    case teal
    case orange

    var id: String { rawValue }
}

enum DockDensity: String, Codable, CaseIterable, Identifiable {
    case compact
    case comfortable

    var id: String { rawValue }
}

enum CollapseSpeed: String, Codable, CaseIterable, Identifiable {
    case fast
    case normal
    case relaxed

    var id: String { rawValue }

    var delay: TimeInterval {
        switch self {
        case .fast: return 0.08
        case .normal: return 0.16
        case .relaxed: return 0.32
        }
    }
}

struct SideDeckPreferences: Codable, Equatable {
    var appearance: AppearanceMode
    var accent: AccentChoice
    var density: DockDensity
    var translucencyEnabled: Bool
    var dockOnRight: Bool
    var keepOpen: Bool
    var collapseSpeed: CollapseSpeed
    var showInDock: Bool
    var visibleWidgets: Set<DockWidgetType>

    static let `default` = SideDeckPreferences(
        appearance: .system,
        accent: .blue,
        density: .compact,
        translucencyEnabled: true,
        dockOnRight: true,
        keepOpen: true,
        collapseSpeed: .normal,
        showInDock: true,
        visibleWidgets: Set(DockWidgetType.allCases)
    )
}

@MainActor
final class SideDeckPreferencesStore: ObservableObject {
    static let storageKey = "sidedeck_preferences_v1"

    @Published private(set) var preferences: SideDeckPreferences
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(SideDeckPreferences.self, from: data),
           !decoded.visibleWidgets.isEmpty {
            preferences = decoded
        } else {
            var migrated = SideDeckPreferences.default
            migrated.dockOnRight = defaults.object(forKey: "isDockOnRight") as? Bool ?? migrated.dockOnRight
            migrated.keepOpen = defaults.object(forKey: "sidedeck_dock_pinned") as? Bool ?? migrated.keepOpen
            migrated.showInDock = defaults.object(forKey: "showInDock") as? Bool ?? migrated.showInDock
            preferences = migrated
            persist()
        }
    }

    func setAppearance(_ value: AppearanceMode) { update { $0.appearance = value } }
    func setAccent(_ value: AccentChoice) { update { $0.accent = value } }
    func setDensity(_ value: DockDensity) { update { $0.density = value } }
    func setTranslucency(_ value: Bool) { update { $0.translucencyEnabled = value } }
    func setDockOnRight(_ value: Bool) { update { $0.dockOnRight = value } }
    func setKeepOpen(_ value: Bool) { update { $0.keepOpen = value } }
    func setCollapseSpeed(_ value: CollapseSpeed) { update { $0.collapseSpeed = value } }
    func setShowInDock(_ value: Bool) { update { $0.showInDock = value } }

    @discardableResult
    func setWidget(_ widget: DockWidgetType, visible: Bool) -> Bool {
        var widgets = preferences.visibleWidgets
        if visible {
            widgets.insert(widget)
        } else {
            guard widgets.count > 1 || !widgets.contains(widget) else { return false }
            widgets.remove(widget)
        }
        update { $0.visibleWidgets = widgets }
        return true
    }

    func reset() {
        preferences = .default
        persist()
    }

    private func update(_ mutation: (inout SideDeckPreferences) -> Void) {
        var next = preferences
        mutation(&next)
        guard next != preferences else { return }
        preferences = next
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
