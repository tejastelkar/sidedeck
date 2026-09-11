# SideDeck Theme, Customization, and Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver SideDeck 1.2 with consistent light/dark UI, reliable controls, real permission-aware Wi-Fi status, real-only habit history, responsive customization, smooth interactions, and crash-safe persistence.

**Architecture:** Extract preferences, theme resolution, Wi-Fi monitoring, layout, and reusable completion controls from the monolithic view while retaining one main-actor application state. UI reads semantic theme tokens and a single preferences store; hardware and persisted inputs are normalized at their boundaries before becoming published state.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, Combine, CoreWLAN, CoreLocation, XCTest, Swift Package Manager, macOS 14+.

**Spec:** `docs/superpowers/specs/2026-09-11-theme-customization-stability-design.md`

## Global Constraints

- Implement inline in the current task; do not dispatch subagents.
- Preserve macOS 14 as the minimum supported version.
- Add no third-party dependencies, cloud sync, analytics, network joining, or drag-and-drop reordering.
- Keep the current graphite identity in dark mode and use cool neutral surfaces in light mode.
- Views must use semantic theme roles for interface colors rather than literal white/black values.
- Keep all published application and service state main-actor isolated.
- Follow red-green-refactor for every production behavior change.
- Preserve existing user tasks, notes, hydration, and clock settings during migration.

---

### Task 1: Commit the validated 1.1.1 baseline

**Files:**
- Modify: existing tracked changes in `Package.swift`, `README.md`, `Casks/sidedeck.rb`, `Sources/SideDeck/SideDeckView.swift`, `Sources/SideDeck/main.swift`, `scripts/package.sh`
- Add: `Tests/SideDeckTests/SideDeckStateTests.swift`, `scripts/render_previews.swift`

**Interfaces:**
- Consumes: the currently verified 1.1.1 working tree.
- Produces: a clean baseline commit before architectural extraction.

- [ ] **Step 1: Re-run baseline tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test`

Expected: 16 tests pass with zero failures.

- [ ] **Step 2: Verify the baseline diff is syntactically clean**

Run: `git diff --check`

Expected: no output and exit status 0.

- [ ] **Step 3: Commit only the validated baseline files**

```bash
git add Package.swift README.md Casks/sidedeck.rb Sources/SideDeck/SideDeckView.swift Sources/SideDeck/main.swift scripts/package.sh Tests/SideDeckTests/SideDeckStateTests.swift scripts/render_previews.swift
git commit -m "fix: stabilize responsive SideDeck 1.1.1"
```

### Task 2: Add persisted preferences and semantic theme resolution

**Files:**
- Create: `Sources/SideDeck/SideDeckPreferences.swift`
- Create: `Sources/SideDeck/SideDeckTheme.swift`
- Create: `Tests/SideDeckTests/SideDeckPreferencesTests.swift`
- Modify: `Sources/SideDeck/SideDeckView.swift`

**Interfaces:**
- Consumes: `DockWidgetType` raw values.
- Produces: `AppearanceMode`, `AccentChoice`, `DockDensity`, `CollapseSpeed`, `SideDeckPreferences`, `SideDeckPreferencesStore`, `ResolvedSideDeckTheme`, and `SideDeckThemeKey`.

- [ ] **Step 1: Write failing preference and resolution tests**

```swift
@MainActor
final class SideDeckPreferencesTests: XCTestCase {
    func testDefaultsFollowSystemAndKeepEveryWidgetVisible() {
        let preferences = SideDeckPreferences.default
        XCTAssertEqual(preferences.appearance, .system)
        XCTAssertEqual(preferences.density, .compact)
        XCTAssertEqual(preferences.visibleWidgets, Set(DockWidgetType.allCases))
    }

    func testSystemAppearanceResolvesAgainstCurrentScheme() {
        XCTAssertEqual(AppearanceMode.system.resolved(system: .light), .light)
        XCTAssertEqual(AppearanceMode.system.resolved(system: .dark), .dark)
        XCTAssertEqual(AppearanceMode.light.resolved(system: .dark), .light)
    }

    func testStorePersistsValidChangesAndRejectsHidingLastWidget() {
        let defaults = isolatedDefaults()
        let store = SideDeckPreferencesStore(defaults: defaults)
        store.setAppearance(.light)
        DockWidgetType.allCases.dropLast().forEach { store.setWidget($0, visible: false) }
        store.setWidget(DockWidgetType.allCases.last!, visible: false)
        let reloaded = SideDeckPreferencesStore(defaults: defaults)
        XCTAssertEqual(reloaded.preferences.appearance, .light)
        XCTAssertEqual(reloaded.preferences.visibleWidgets.count, 1)
    }
}
```

The test utility creates and destroys an isolated `UserDefaults` suite; production code exposes no test-only cleanup method.

- [ ] **Step 2: Run the tests and confirm the types are missing**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --filter SideDeckPreferencesTests`

Expected: compilation fails because `SideDeckPreferences` and related types do not exist.

- [ ] **Step 3: Implement Codable preferences and guarded mutations**

```swift
enum AppearanceMode: String, Codable, CaseIterable { case system, dark, light }
enum AccentChoice: String, Codable, CaseIterable { case system, blue, indigo, teal, orange }
enum DockDensity: String, Codable, CaseIterable { case compact, comfortable }
enum CollapseSpeed: String, Codable, CaseIterable {
    case fast, normal, relaxed
    var delay: TimeInterval { self == .fast ? 0.08 : self == .normal ? 0.16 : 0.32 }
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
}
```

`SideDeckPreferencesStore` loads one JSON value from `sidedeck_preferences_v1`, falls back to `.default` on missing/corrupt data, immediately persists valid mutations, and refuses to remove the last visible widget.

- [ ] **Step 4: Implement semantic theme resolution**

`AppearanceMode.resolved(system:)` returns the effective `ColorScheme`. `ResolvedSideDeckTheme` supplies the semantic roles from the spec and resolves the accent choice. Add a SwiftUI environment key and a root modifier that injects the palette and applies `.preferredColorScheme(nil/.dark/.light)` according to the preference.

- [ ] **Step 5: Run focused and full tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --filter SideDeckPreferencesTests`

Expected: all preference tests pass.

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test`

Expected: all tests pass.

- [ ] **Step 6: Commit the preference and theme foundation**

```bash
git add Sources/SideDeck/SideDeckPreferences.swift Sources/SideDeck/SideDeckTheme.swift Sources/SideDeck/SideDeckView.swift Tests/SideDeckTests/SideDeckPreferencesTests.swift
git commit -m "feat: add SideDeck appearance preferences"
```

### Task 3: Standardize completion controls and eliminate click propagation

**Files:**
- Create: `Sources/SideDeck/CompletionToggle.swift`
- Create: `Tests/SideDeckTests/CompletionBehaviorTests.swift`
- Modify: `Sources/SideDeck/SideDeckView.swift`

**Interfaces:**
- Consumes: `ResolvedSideDeckTheme`, `ChecklistItem`, `SideDeckState.toggleTask(_:)`, and `SideDeckState.toggleNote(_:)`.
- Produces: `CompletionToggle(label:isCompleted:size:action:)` and `CompletionControlSize.compact/regular`.

- [ ] **Step 1: Write failing completion behavior tests**

```swift
@MainActor
final class CompletionBehaviorTests: XCTestCase {
    func testCompletionControlSizesMeetTheirHitTargets() {
        XCTAssertEqual(CompletionControlSize.compact.hitTarget, 18)
        XCTAssertEqual(CompletionControlSize.regular.hitTarget, 24)
    }

    func testNoteCompletionTogglesOnceAndPersists() {
        let defaults = isolatedDefaults()
        let state = SideDeckState(defaults: defaults, startServices: false)
        let note = ChecklistItem(text: "Verify release", isDone: false)
        state.noteLines = [note]
        state.toggleNote(note)
        XCTAssertTrue(state.noteLines[0].isDone)
        XCTAssertTrue(SideDeckState(defaults: defaults, startServices: false).noteLines[0].isDone)
    }

    func testMissingNoteIsIgnoredWithoutMutation() {
        let state = SideDeckState(defaults: isolatedDefaults(), startServices: false)
        state.noteLines = [ChecklistItem(text: "Keep", isDone: false)]
        state.toggleNote(ChecklistItem(text: "Missing", isDone: false))
        XCTAssertEqual(state.noteLines.map(\.text), ["Keep"])
    }
}
```

- [ ] **Step 2: Run the test and verify the new control contract is missing**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --filter CompletionBehaviorTests`

Expected: compilation fails because `CompletionControlSize` does not exist.

- [ ] **Step 3: Build the shared completion control**

The control owns the circle, border, accent fill, checkmark, hit target, accessibility value, and reduce-motion-aware confirmation animation. It accepts one action closure and contains no parent-card gesture.

```swift
struct CompletionToggle: View {
    let label: String
    let isCompleted: Bool
    let size: CompletionControlSize
    let action: () -> Void
}
```

Replace task and note circles in both compact cards and expanded flyouts. Wrap card-opening gestures around non-control content rather than the entire card so a completion click cannot also select the card.

- [ ] **Step 4: Replace literal interface colors with semantic roles**

Convert every user-interface `Color.white`, `.white`, `Color.black`, and embedded surface hex in `SideDeckView.swift` to the matching palette role. Keep white/black only when it is data visualization content whose meaning is intensity and document those two call sites with `// Heatmap intensity endpoint`.

- [ ] **Step 5: Run completion and full tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --filter CompletionBehaviorTests`

Expected: all completion tests pass.

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test`

Expected: all tests pass.

- [ ] **Step 6: Commit standardized controls**

```bash
git add Sources/SideDeck/CompletionToggle.swift Sources/SideDeck/SideDeckView.swift Tests/SideDeckTests/CompletionBehaviorTests.swift
git commit -m "fix: standardize completion interactions"
```

### Task 4: Make hover and click transitions deterministic

**Files:**
- Create: `Sources/SideDeck/SideDeckInteractionState.swift`
- Create: `Tests/SideDeckTests/SideDeckInteractionStateTests.swift`
- Modify: `Sources/SideDeck/SideDeckView.swift`
- Modify: `Sources/SideDeck/main.swift`

**Interfaces:**
- Consumes: `DockWidgetType`, `CollapseSpeed.delay`, and `SideDeckHostDelegate`.
- Produces: `SideDeckInteractionState`, `hoverCard(_:)`, `exitCard(_:)`, `selectCard(_:)`, `hoverFlyout(_:)`, `requestCollapse()`, and idempotent `transitionCount` observable in tests.

- [ ] **Step 1: Write failing interaction tests**

```swift
@MainActor
func testRepeatedHoverDoesNotCreateAnotherTransition() {
    let state = SideDeckInteractionState(collapseDelay: 0.01)
    state.hoverCard(.clock)
    let count = state.transitionCount
    state.hoverCard(.clock)
    XCTAssertEqual(state.transitionCount, count)
}

@MainActor
func testClickedSelectionSurvivesCardAndFlyoutExit() async throws {
    let state = SideDeckInteractionState(collapseDelay: 0.01)
    state.hoverCard(.notes)
    state.selectCard(.notes)
    state.exitCard(.notes)
    state.hoverFlyout(false)
    try await Task.sleep(for: .milliseconds(80))
    XCTAssertEqual(state.selectedWidget, .notes)
    XCTAssertEqual(state.activeWidget, .notes)
}
```

Retain and move the existing stale-exit, pinned-collapse, and click-toggle tests into this test file.

- [ ] **Step 2: Run interaction tests and verify failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --filter SideDeckInteractionStateTests`

Expected: compilation fails because the new coordinator does not exist.

- [ ] **Step 3: Implement a guarded state machine**

Store `hoveredWidget`, `selectedWidget`, `isHoveringFlyout`, `isDockCollapsed`, and one cancellable `DispatchWorkItem`. Centralize published `activeWidget` derivation and increment `transitionCount` only when visible state actually changes. Embedded controls remain plain buttons outside the parent card-opening gesture.

- [ ] **Step 4: Respect Reduce Motion in the view**

Read `accessibilityReduceMotion`; use opacity-only transitions when true and one short spring/scale transition otherwise. Remove implicit animations from individual child cards where the root transition already animates the same value.

- [ ] **Step 5: Run focused and full tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --filter SideDeckInteractionStateTests`

Expected: all interaction tests pass.

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test`

Expected: all tests pass.

- [ ] **Step 6: Commit interaction stability**

```bash
git add Sources/SideDeck/SideDeckInteractionState.swift Sources/SideDeck/SideDeckView.swift Sources/SideDeck/main.swift Tests/SideDeckTests/SideDeckInteractionStateTests.swift Tests/SideDeckTests/SideDeckStateTests.swift
git commit -m "fix: make dock interactions deterministic"
```

### Task 5: Add permission-aware Wi-Fi monitoring

**Files:**
- Create: `Sources/SideDeck/WiFiMonitor.swift`
- Create: `Tests/SideDeckTests/WiFiMonitorTests.swift`
- Modify: `Sources/SideDeck/SideDeckView.swift`
- Modify: `Sources/SideDeck/main.swift`
- Modify: `scripts/package.sh`

**Interfaces:**
- Consumes: CoreWLAN `CWInterface`, CoreLocation `CLLocationManager`, app lifecycle notifications.
- Produces: `WiFiSnapshot`, `WiFiAuthorization`, `WiFiReadingProviding`, `LocationAuthorizationProviding`, and main-actor `WiFiMonitor` with `refresh()`, `requestNetworkNameAccess()`, and `openLocationSettings()`.

- [ ] **Step 1: Write failing service tests with boundary fakes**

```swift
@MainActor
func testAuthorizedMonitorPublishesActualSSID() {
    let monitor = WiFiMonitor(
        wifi: FakeWiFi(powered: true, ssid: "Studio WiFi", rssi: -48),
        location: FakeLocation(status: .authorized)
    )
    monitor.refresh()
    XCTAssertEqual(monitor.snapshot.networkName, "Studio WiFi")
    XCTAssertEqual(monitor.snapshot.connection, .connected)
}

@MainActor
func testDeniedMonitorExplainsWhyNameIsUnavailable() {
    let monitor = WiFiMonitor(
        wifi: FakeWiFi(powered: true, ssid: nil, rssi: -55),
        location: FakeLocation(status: .denied)
    )
    monitor.refresh()
    XCTAssertEqual(monitor.snapshot.displayName, "Allow Location Access")
}
```

Also cover missing interface, Wi-Fi off, authorized nil SSID, and unchanged snapshots.

- [ ] **Step 2: Run Wi-Fi tests and verify missing-type failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --filter WiFiMonitorTests`

Expected: compilation fails because `WiFiMonitor` does not exist.

- [ ] **Step 3: Implement providers and monitor**

CoreWLAN provider reads power, SSID, and RSSI without force unwraps. CoreLocation provider maps authorization values, requests when-in-use access only from the explicit action/status flyout, and forwards changes. `WiFiMonitor` publishes only changed snapshots on the main actor.

- [ ] **Step 4: Wire status views and permission actions**

Replace `SideDeckState` Wi-Fi fields with the injected monitor. Show the SSID only when present; otherwise show the precise `Connected network`, `Allow Location Access`, `Wi-Fi Off`, or `No Wi-Fi Interface` state. Add Refresh and Open Location Settings actions where applicable.

- [ ] **Step 5: Add the bundle permission description**

Add this generated plist entry in `scripts/package.sh`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>SideDeck uses your location permission only to display the name of the Wi-Fi network connected to this Mac.</string>
```

- [ ] **Step 6: Run focused and full tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --filter WiFiMonitorTests`

Expected: all Wi-Fi tests pass.

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test`

Expected: all tests pass.

- [ ] **Step 7: Commit Wi-Fi monitoring**

```bash
git add Sources/SideDeck/WiFiMonitor.swift Sources/SideDeck/SideDeckView.swift Sources/SideDeck/main.swift scripts/package.sh Tests/SideDeckTests/WiFiMonitorTests.swift
git commit -m "fix: show permission-aware Wi-Fi status"
```

### Task 6: Migrate generated habit history and add safe reset

**Files:**
- Create: `Tests/SideDeckTests/HabitHistoryTests.swift`
- Modify: `Sources/SideDeck/SideDeckState.swift`
- Modify: `Sources/SideDeck/SideDeckView.swift`

**Interfaces:**
- Consumes: legacy keys `sidedeck_habits`, `sidedeck_annual_habits`, `sidedeck_habit_today_count`, `sidedeck_habit_streak`, and `sidedeck_habit_last_checkin`.
- Produces: migration key `sidedeck_real_habits_migration_v1`, `migrateLegacyHabitHistoryIfNeeded(on:)`, and `resetHabitHistory()`.

- [ ] **Step 1: Write failing migration and reset tests**

```swift
@MainActor
func testLegacyGeneratedHistoryMigratesToOneCheckInExactlyOnce() {
    let defaults = isolatedDefaults()
    defaults.set(Array(repeating: 3, count: 140), forKey: "sidedeck_annual_habits")
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let state = SideDeckState(defaults: defaults, startServices: false, now: date)
    XCTAssertEqual(state.annualHabitMatrix.filter { $0 > 0 }.count, 1)
    XCTAssertEqual(state.annualHabitMatrix.last, 1)
    XCTAssertEqual(state.habitTodayCount, 1)

    state.annualHabitMatrix[0] = 2
    state.saveHabits()
    let reloaded = SideDeckState(defaults: defaults, startServices: false, now: date)
    XCTAssertEqual(reloaded.annualHabitMatrix[0], 2)
}

@MainActor
func testResetOnlyClearsHabitData() {
    let state = seededState()
    let notes = state.noteLines
    state.resetHabitHistory()
    XCTAssertTrue(state.annualHabitMatrix.allSatisfy { $0 == 0 })
    XCTAssertEqual(state.habitTodayCount, 0)
    XCTAssertEqual(state.noteLines, notes)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --filter HabitHistoryTests`

Expected: compilation fails because the migration/reset APIs are missing.

- [ ] **Step 3: Implement normalization, one-time migration, and reset**

Normalize compact history to 36 entries and annual history to 140 entries, clamping values to `0...4`. Detect legacy generated history only when the migration key is absent and a nonempty legacy matrix exists. Persist cleaned matrices and counters, then write the migration key last. New empty installations remain empty.

- [ ] **Step 4: Add confirmed Reset History UI**

Settings Data section opens an `NSAlert` confirmation. Confirm calls `resetHabitHistory()`; Cancel performs no mutation. After reset, `checkInToday(on:)` creates one level-1 final cell and count/streak 1.

- [ ] **Step 5: Run focused and full tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --filter HabitHistoryTests`

Expected: all history tests pass.

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test`

Expected: all tests pass.

- [ ] **Step 6: Commit habit-history correctness**

```bash
git add Sources/SideDeck/SideDeckState.swift Sources/SideDeck/SideDeckView.swift Tests/SideDeckTests/HabitHistoryTests.swift
git commit -m "fix: replace generated habits with real history"
```

### Task 7: Build settings UI and responsive widget layout

**Files:**
- Create: `Sources/SideDeck/SideDeckLayout.swift`
- Create: `Sources/SideDeck/SettingsFlyout.swift`
- Create: `Tests/SideDeckTests/ResponsiveLayoutTests.swift`
- Modify: `Sources/SideDeck/SideDeckView.swift`
- Modify: `Sources/SideDeck/main.swift`

**Interfaces:**
- Consumes: `SideDeckPreferencesStore`, `ResolvedSideDeckTheme`, visible widget set, `SideDeckInteractionState`, and state reset APIs.
- Produces: density-aware `SideDeckLayout`, `SettingsFlyout`, and `SideDeckHostDelegate.applyPreferences()`.

- [ ] **Step 1: Write failing responsive layout tests**

```swift
func testShortScreenKeepsControlsReachable() {
    let layout = SideDeckLayout(
        availableSize: CGSize(width: 900, height: 430),
        density: .comfortable,
        visibleWidgets: Set(DockWidgetType.allCases)
    )
    XCTAssertLessThanOrEqual(layout.panelSize.height, 410)
    XCTAssertTrue(layout.requiresRailScrolling)
    XCTAssertGreaterThan(layout.persistentControlsHeight, 0)
}

func testNarrowWideFlyoutUsesSingleColumn() {
    let layout = SideDeckLayout(
        availableSize: CGSize(width: 480, height: 700),
        density: .compact,
        visibleWidgets: Set(DockWidgetType.allCases)
    )
    XCTAssertEqual(layout.wideFlyoutArrangement, .singleColumn)
    XCTAssertGreaterThanOrEqual(layout.flyoutFrame(for: .water, dockOnRight: true).minX, 0)
}
```

Also cover both dock edges, hidden widgets, one-widget layout, and hit-region equality.

- [ ] **Step 2: Run layout tests and verify initializer failure**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --filter ResponsiveLayoutTests`

Expected: compilation fails because density/visibility layout inputs do not exist.

- [ ] **Step 3: Extract and extend layout authority**

Move `SideDeckLayout` from the view file. Derive card sizes, panel size, scroll requirement, flyout arrangement, frames, callout position, and hit regions from screen, density, and visible widgets. Water and habits switch to vertical content when `wideFlyoutArrangement == .singleColumn`.

- [ ] **Step 4: Implement the settings flyout**

Use compact segmented controls and toggles for every option in the spec. The ellipsis button opens/closes this flyout through interaction state rather than the status menu. Preference changes apply live. Show an inline explanation when the last visible widget cannot be hidden.

- [ ] **Step 5: Wire preferences through the app host**

`AppDelegate` owns one preferences store and passes it to the root. `applyPreferences()` updates activation policy, side, panel geometry, pin state, and menu checks without constructing a new `SideDeckState` or `WiFiMonitor`.

- [ ] **Step 6: Run focused and full tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --filter ResponsiveLayoutTests`

Expected: all responsive layout tests pass.

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test`

Expected: all tests pass.

- [ ] **Step 7: Commit customization and responsive layout**

```bash
git add Sources/SideDeck/SideDeckLayout.swift Sources/SideDeck/SettingsFlyout.swift Sources/SideDeck/SideDeckView.swift Sources/SideDeck/main.swift Tests/SideDeckTests/ResponsiveLayoutTests.swift
git commit -m "feat: add responsive SideDeck customization"
```

### Task 8: Harden persistence and lifecycle boundaries

**Files:**
- Create: `Tests/SideDeckTests/PersistenceSafetyTests.swift`
- Modify: `Sources/SideDeck/SideDeckState.swift`
- Modify: `Sources/SideDeck/SideDeckPreferences.swift`
- Modify: `Sources/SideDeck/WiFiMonitor.swift`
- Modify: `Sources/SideDeck/main.swift`

**Interfaces:**
- Consumes: all persisted keys, timers, observers, and system-service providers.
- Produces: validating decode helpers, normalized state initialization, and explicit lifecycle cleanup.

- [ ] **Step 1: Write failing malformed-data tests**

```swift
@MainActor
func testCorruptPersistedDataCreatesSafeState() {
    let defaults = isolatedDefaults()
    defaults.set(Data([0xFF, 0x00]), forKey: "sidedeck_notes")
    defaults.set([-5, 99], forKey: "sidedeck_habits")
    defaults.set(-400, forKey: "sidedeck_water_ml")
    let state = SideDeckState(defaults: defaults, startServices: false)
    XCTAssertTrue(state.noteLines.isEmpty)
    XCTAssertEqual(state.habitMatrix.count, 36)
    XCTAssertTrue(state.habitMatrix.allSatisfy { (0...4).contains($0) })
    XCTAssertEqual(state.waterMl, 0)
}
```

Add preference corrupt-JSON recovery and missing-screen/provider nil-state tests.

- [ ] **Step 2: Run safety tests and verify incorrect current values**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --filter PersistenceSafetyTests`

Expected: tests fail because current loaders accept invalid numeric collections or legacy sample defaults.

- [ ] **Step 3: Add validating loaders and lifecycle cleanup**

Decode tasks/notes with typed helpers returning empty arrays on failure. Normalize all bounded numeric values. Store cancellables and notification tokens in their owning types and cancel/remove them in `deinit`. Ensure callbacks hop to `MainActor` before updating published properties.

- [ ] **Step 4: Run focused, full, and repeated tests**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --filter PersistenceSafetyTests`

Expected: all safety tests pass.

Run: `for run in 1 2 3; do DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test || exit 1; done`

Expected: three consecutive complete runs pass without crashes or intermittent failures.

- [ ] **Step 5: Commit stability hardening**

```bash
git add Sources/SideDeck/SideDeckState.swift Sources/SideDeck/SideDeckPreferences.swift Sources/SideDeck/WiFiMonitor.swift Sources/SideDeck/main.swift Tests/SideDeckTests/PersistenceSafetyTests.swift
git commit -m "fix: harden SideDeck persistence and lifecycle"
```

### Task 9: Render, live-test, package, and install SideDeck 1.2

**Files:**
- Modify: `scripts/render_previews.swift`
- Modify: `scripts/package.sh`
- Modify: `README.md`
- Modify: `Casks/sidedeck.rb`

**Interfaces:**
- Consumes: complete theme, preferences, interaction, Wi-Fi, habit, and responsive implementation.
- Produces: SideDeck 1.2 installed app and `build/SideDeck-1.2.0.dmg`.

- [ ] **Step 1: Extend visual rendering matrix**

Render every widget flyout plus settings in dark and light modes, both dock edges, 480-point narrow width, 430-point short height, compact and comfortable density, reduced-motion environment, and a hidden-widget configuration. Save previews under `/tmp/sidedeck-previews/`.

- [ ] **Step 2: Inspect every rendered image**

Verify no clipping, inconsistent completion marks, unreadable text, off-canvas shadows, inaccessible settings, or literal dark-only surfaces in light mode. Correct each visual defect and rerun the full render matrix.

- [ ] **Step 3: Run release verification**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test`

Expected: all tests pass.

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift build -c release`

Expected: release build exits 0 without compiler errors.

Run: `git diff --check`

Expected: no output.

- [ ] **Step 4: Version and package**

Set `APP_VERSION="1.2.0"`, increment the bundle build number, update README/Cask filenames, then run `./scripts/package.sh --install`. Calculate the DMG SHA-256 and place it in `Casks/sidedeck.rb`.

- [ ] **Step 5: Verify installed artifacts**

Run `codesign --verify --deep --strict --verbose=2 /Applications/SideDeck.app`, `hdiutil verify build/SideDeck-1.2.0.dmg`, `ruby -c Casks/sidedeck.rb`, and inspect the installed Info.plist. Each command must exit 0 and the bundle version must be 1.2.0.

- [ ] **Step 6: Live-test the installed application**

Verify Auto/Dark/Light changes, one-click note completion and persistence, repeated open/close clicks, hover handoff, pin/collapse, every settings option, habit history showing one real check-in, reset confirmation, and Wi-Fi permission messaging. If Location is authorized, verify the displayed SSID equals CoreWLAN's returned SSID; otherwise verify the permission action and honest fallback.

- [ ] **Step 7: Remove redundant artifacts and commit release metadata**

Keep `/Applications/SideDeck.app` and `build/SideDeck-1.2.0.dmg`; move redundant unpacked app copies and older DMGs to Trash.

```bash
git add scripts/render_previews.swift scripts/package.sh README.md Casks/sidedeck.rb
git commit -m "release: package SideDeck 1.2.0"
```
