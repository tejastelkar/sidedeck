import Combine
import SwiftUI

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

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
    var title: String { rawValue.capitalized }
}

enum DockDensity: String, Codable, CaseIterable, Identifiable {
    case compact
    case comfortable

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum CollapseSpeed: String, Codable, CaseIterable, Identifiable {
    case fast
    case normal
    case relaxed

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

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
    var glowEnabled: Bool
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
        glowEnabled: true,
        dockOnRight: true,
        keepOpen: true,
        collapseSpeed: .normal,
        showInDock: true,
        visibleWidgets: Set(DockWidgetType.allCases)
    )

    private enum CodingKeys: String, CodingKey {
        case appearance, accent, density, translucencyEnabled, glowEnabled
        case dockOnRight, keepOpen, collapseSpeed, showInDock, visibleWidgets
    }

    init(
        appearance: AppearanceMode,
        accent: AccentChoice,
        density: DockDensity,
        translucencyEnabled: Bool,
        glowEnabled: Bool,
        dockOnRight: Bool,
        keepOpen: Bool,
        collapseSpeed: CollapseSpeed,
        showInDock: Bool,
        visibleWidgets: Set<DockWidgetType>
    ) {
        self.appearance = appearance
        self.accent = accent
        self.density = density
        self.translucencyEnabled = translucencyEnabled
        self.glowEnabled = glowEnabled
        self.dockOnRight = dockOnRight
        self.keepOpen = keepOpen
        self.collapseSpeed = collapseSpeed
        self.showInDock = showInDock
        self.visibleWidgets = visibleWidgets
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        appearance = try values.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? Self.default.appearance
        accent = try values.decodeIfPresent(AccentChoice.self, forKey: .accent) ?? Self.default.accent
        density = try values.decodeIfPresent(DockDensity.self, forKey: .density) ?? Self.default.density
        translucencyEnabled = try values.decodeIfPresent(Bool.self, forKey: .translucencyEnabled) ?? Self.default.translucencyEnabled
        glowEnabled = try values.decodeIfPresent(Bool.self, forKey: .glowEnabled) ?? true
        dockOnRight = try values.decodeIfPresent(Bool.self, forKey: .dockOnRight) ?? Self.default.dockOnRight
        keepOpen = try values.decodeIfPresent(Bool.self, forKey: .keepOpen) ?? Self.default.keepOpen
        collapseSpeed = try values.decodeIfPresent(CollapseSpeed.self, forKey: .collapseSpeed) ?? Self.default.collapseSpeed
        showInDock = try values.decodeIfPresent(Bool.self, forKey: .showInDock) ?? Self.default.showInDock
        visibleWidgets = try values.decodeIfPresent(Set<DockWidgetType>.self, forKey: .visibleWidgets) ?? Self.default.visibleWidgets
    }
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
    func setGlowEnabled(_ value: Bool) { update { $0.glowEnabled = value } }
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
