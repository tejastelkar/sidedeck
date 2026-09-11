import SwiftUI
import XCTest
@testable import SideDeck

@MainActor
final class SideDeckPreferencesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "SideDeckPreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsFollowSystemAndKeepEveryWidgetVisible() {
        let preferences = SideDeckPreferences.default

        XCTAssertEqual(preferences.appearance, .system)
        XCTAssertEqual(preferences.density, .compact)
        XCTAssertTrue(preferences.glowEnabled)
        XCTAssertEqual(preferences.visibleWidgets, Set(DockWidgetType.allCases))
    }

    func testAppearanceResolvesAgainstCurrentScheme() {
        XCTAssertEqual(AppearanceMode.system.resolved(system: .light), .light)
        XCTAssertEqual(AppearanceMode.system.resolved(system: .dark), .dark)
        XCTAssertEqual(AppearanceMode.light.resolved(system: .dark), .light)
        XCTAssertEqual(AppearanceMode.dark.resolved(system: .light), .dark)
    }

    func testStorePersistsChangesAndRejectsHidingLastWidget() {
        let store = SideDeckPreferencesStore(defaults: defaults)
        store.setAppearance(.light)
        for widget in DockWidgetType.allCases.dropLast() {
            XCTAssertTrue(store.setWidget(widget, visible: false))
        }
        XCTAssertFalse(store.setWidget(DockWidgetType.allCases.last!, visible: false))

        let reloaded = SideDeckPreferencesStore(defaults: defaults)

        XCTAssertEqual(reloaded.preferences.appearance, .light)
        XCTAssertEqual(reloaded.preferences.visibleWidgets.count, 1)
    }

    func testCorruptPreferencesFallBackToSafeDefaults() {
        defaults.set(Data([0xFF, 0x00]), forKey: SideDeckPreferencesStore.storageKey)

        let store = SideDeckPreferencesStore(defaults: defaults)

        XCTAssertEqual(store.preferences, .default)
    }

    func testGlowPreferencePersists() {
        let store = SideDeckPreferencesStore(defaults: defaults)

        store.setGlowEnabled(false)
        let reloaded = SideDeckPreferencesStore(defaults: defaults)

        XCTAssertFalse(reloaded.preferences.glowEnabled)
    }

    func testOlderPreferencesWithoutGlowKeepTheirValuesAndDefaultGlowOn() throws {
        let legacyJSON = """
        {"appearance":"light","accent":"teal","density":"comfortable","translucencyEnabled":false,"dockOnRight":false,"keepOpen":false,"collapseSpeed":"fast","showInDock":false,"visibleWidgets":["notes"]}
        """
        defaults.set(try XCTUnwrap(legacyJSON.data(using: .utf8)), forKey: SideDeckPreferencesStore.storageKey)

        let store = SideDeckPreferencesStore(defaults: defaults)

        XCTAssertEqual(store.preferences.appearance, .light)
        XCTAssertEqual(store.preferences.visibleWidgets, [.notes])
        XCTAssertTrue(store.preferences.glowEnabled)
    }
}
