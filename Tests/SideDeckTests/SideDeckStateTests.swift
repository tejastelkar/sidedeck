import XCTest
import SwiftUI
@testable import SideDeck

@MainActor
final class SideDeckStateTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "SideDeckTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testTimerStopsWhenFocusCountdownReachesZero() {
        let state = SideDeckState(defaults: defaults, startServices: false)
        state.focusRemaining = 1
        state.isFocusRunning = true

        state.advanceOneSecond(now: Date(timeIntervalSince1970: 10))

        XCTAssertEqual(state.focusRemaining, 0)
        XCTAssertFalse(state.isFocusRunning)
    }

    func testNegativeHabitIndexesAreIgnored() {
        let state = SideDeckState(defaults: defaults, startServices: false)
        let original = state.habitMatrix

        state.toggleHabitCell(at: -1)
        state.toggleAnnualHabitCell(at: -1)

        XCTAssertEqual(state.habitMatrix, original)
    }

    func testAddingWaterRejectsNonPositiveAmountsWithoutChangingHabits() {
        let state = SideDeckState(defaults: defaults, startServices: false)
        let originalWater = state.waterMl
        let originalCheckIns = state.habitTodayCount

        state.addDrink(amount: -250)

        XCTAssertEqual(state.waterMl, originalWater)
        XCTAssertEqual(state.habitTodayCount, originalCheckIns)
    }

    func testCompletingActiveTaskSelectsNextPendingTask() {
        let state = SideDeckState(defaults: defaults, startServices: false)
        state.subtasks = [
            ChecklistItem(text: "First", isDone: false),
            ChecklistItem(text: "Second", isDone: false)
        ]
        state.taskName = "First"

        state.toggleTask(state.subtasks[0])

        XCTAssertEqual(state.taskName, "Second")
    }

    func testHabitCheckInCountsOnlyOncePerCalendarDay() {
        let state = SideDeckState(defaults: defaults, startServices: false)
        state.habitTodayCount = 0
        state.habitStreak = 0
        let today = Date(timeIntervalSince1970: 1_800_000_000)

        state.checkInToday(on: today)
        state.checkInToday(on: today.addingTimeInterval(60))

        XCTAssertEqual(state.habitTodayCount, 1)
        XCTAssertEqual(state.habitStreak, 1)
    }

    func testFreshHabitHistoryStartsEmpty() {
        let state = SideDeckState(defaults: defaults, startServices: false)

        XCTAssertEqual(state.habitMatrix, Array(repeating: 0, count: 36))
        XCTAssertEqual(state.annualHabitMatrix, Array(repeating: 0, count: 140))
        XCTAssertEqual(state.habitTodayCount, 0)
        XCTAssertEqual(state.habitStreak, 0)
    }

    func testLegacyDemoHistoryMigratesToOneRealCheckInOnlyOnce() {
        defaults.set(Array(repeating: 4, count: 36), forKey: "sidedeck_habits")
        defaults.set(Array(repeating: 3, count: 140), forKey: "sidedeck_annual_habits")
        defaults.set(8, forKey: "sidedeck_habit_today_count")
        defaults.set(12, forKey: "sidedeck_habit_streak")
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let migrated = SideDeckState(defaults: defaults, startServices: false, now: now)

        XCTAssertEqual(migrated.habitMatrix.filter { $0 > 0 }.count, 1)
        XCTAssertEqual(migrated.habitMatrix.last, 1)
        XCTAssertEqual(migrated.annualHabitMatrix.filter { $0 > 0 }.count, 1)
        XCTAssertEqual(migrated.annualHabitMatrix.last, 1)
        XCTAssertEqual(migrated.habitTodayCount, 1)
        XCTAssertEqual(migrated.habitStreak, 1)

        migrated.toggleAnnualHabitCell(at: 0)
        let reloaded = SideDeckState(defaults: defaults, startServices: false, now: now)
        XCTAssertEqual(reloaded.annualHabitMatrix[0], 1)
    }

    func testResetHabitHistoryClearsAllCountersAndPersists() {
        let state = SideDeckState(defaults: defaults, startServices: false)
        state.checkInToday(on: Date(timeIntervalSince1970: 1_800_000_000))

        state.resetHabitHistory()
        let reloaded = SideDeckState(defaults: defaults, startServices: false)

        XCTAssertEqual(reloaded.habitTodayCount, 0)
        XCTAssertEqual(reloaded.habitStreak, 0)
        XCTAssertTrue(reloaded.habitMatrix.allSatisfy { $0 == 0 })
        XCTAssertTrue(reloaded.annualHabitMatrix.allSatisfy { $0 == 0 })
    }
}

@MainActor
final class SideDeckHoverStateTests: XCTestCase {
    func testRepeatedHoverDoesNotCreateExtraStateTransitions() {
        let state = SideDeckHoverState()

        state.hoverCard(.focus)
        let transitions = state.transitionCount
        state.hoverCard(.focus)

        XCTAssertEqual(state.transitionCount, transitions)
        XCTAssertEqual(state.activeWidget, .focus)
    }

    func testLateExitFromPreviousCardDoesNotCollapseNewCard() async throws {
        let state = SideDeckHoverState()
        state.hoverCard(.focus)
        state.hoverCard(.clock)

        state.exitCard(.focus)
        try await Task.sleep(for: .milliseconds(250))

        XCTAssertEqual(state.activeWidget, .clock)
    }

    func testUnpinnedDockCollapsesAfterPointerLeaves() async throws {
        let suiteName = "SideDeckHoverTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = SideDeckHoverState(defaults: defaults, collapseDelay: 0.01)
        state.setPinned(false)
        state.expandDock()
        state.hoverCard(.focus)

        state.exitCard(.focus)
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertTrue(state.isDockCollapsed)
        XCTAssertNil(state.activeWidget)
    }

    func testPinnedDockClosesFlyoutWithoutCollapsingRail() async throws {
        let suiteName = "SideDeckHoverTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = SideDeckHoverState(defaults: defaults, collapseDelay: 0.01)
        state.setPinned(true)
        state.hoverCard(.focus)

        state.exitCard(.focus)
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertFalse(state.isDockCollapsed)
        XCTAssertNil(state.activeWidget)
    }

    func testCardActivationTogglesAndSwitchesFlyouts() {
        let state = SideDeckHoverState()

        state.toggleCard(.focus)
        XCTAssertEqual(state.activeWidget, .focus)

        state.toggleCard(.clock)
        XCTAssertEqual(state.activeWidget, .clock)

        state.toggleCard(.clock)
        XCTAssertNil(state.activeWidget)
    }

    func testClickedFlyoutSurvivesDelayedHoverExit() async throws {
        let suiteName = "SideDeckClickTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = SideDeckHoverState(defaults: defaults, collapseDelay: 0.01)
        state.setPinned(true)

        state.hoverCard(.habits)
        state.toggleCard(.habits)
        state.exitCard(.habits)
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(state.activeWidget, .habits)
    }

    func testSettingsAndWidgetFlyoutsAreMutuallyExclusive() {
        let state = SideDeckHoverState()

        state.toggleSettings()
        XCTAssertTrue(state.isSettingsOpen)
        XCTAssertNil(state.activeWidget)

        state.toggleCard(.notes)
        XCTAssertFalse(state.isSettingsOpen)
        XCTAssertEqual(state.activeWidget, .notes)
    }

    func testEnteringSettingsFlyoutDoesNotCloseSettings() {
        let state = SideDeckHoverState()
        state.toggleSettings()

        state.hoverFlyout()

        XCTAssertTrue(state.isSettingsOpen)
        XCTAssertTrue(state.isHoveringFlyout)
    }
}

final class SideDeckLayoutTests: XCTestCase {
    func testFlyoutAnchorFollowsVisibleWidgetOrder() {
        let layout = SideDeckLayout.preferred
        let visible: Set<DockWidgetType> = [.battery, .notes]

        XCTAssertLessThan(
            layout.dockCardCenterY(for: .battery, visibleWidgets: visible, spacing: 4.2),
            layout.dockCardCenterY(for: .notes, visibleWidgets: visible, spacing: 4.2)
        )
        XCTAssertEqual(
            layout.dockCardCenterY(for: .battery, visibleWidgets: visible, spacing: 4.2),
            SideDeckLayout.dockTopInset + SideDeckLayout.dockPadding + 55.4 / 2,
            accuracy: 0.01
        )
    }
    func testWideFlyoutFitsInsidePanelOnBothDockEdges() {
        let layout = SideDeckLayout(availableSize: CGSize(width: 1_000, height: 900))
        let bounds = CGRect(origin: .zero, size: layout.panelSize)

        let rightFrame = layout.flyoutFrame(for: .habits, in: bounds, dockOnRight: true)
        let leftFrame = layout.flyoutFrame(for: .habits, in: bounds, dockOnRight: false)

        XCTAssertGreaterThanOrEqual(rightFrame.minX, 20)
        XCTAssertLessThanOrEqual(rightFrame.maxX, bounds.maxX)
        XCTAssertGreaterThanOrEqual(leftFrame.minX, bounds.minX)
        XCTAssertLessThanOrEqual(leftFrame.maxX, bounds.maxX - 20)
    }

    func testLayoutShrinksWideFlyoutToNarrowScreensWithoutClipping() {
        let layout = SideDeckLayout(availableSize: CGSize(width: 520, height: 600))
        let bounds = CGRect(origin: .zero, size: layout.panelSize)
        let frame = layout.flyoutFrame(for: .water, in: bounds, dockOnRight: true)

        XCTAssertEqual(layout.panelSize.width, 520)
        XCTAssertGreaterThanOrEqual(frame.minX, bounds.minX)
        XCTAssertLessThanOrEqual(frame.maxX, bounds.maxX)
        XCTAssertLessThanOrEqual(layout.panelSize.height, 580)
    }

    func testEveryFlyoutPlacementStaysInsideVisiblePanelHeight() {
        let layout = SideDeckLayout(availableSize: CGSize(width: 1_000, height: 600))

        for widget in DockWidgetType.allCases {
            let frame = layout.flyoutFrame(for: widget, dockOnRight: true)
            XCTAssertGreaterThanOrEqual(frame.minY, SideDeckLayout.screenVerticalMargin, "\(widget) clipped at top")
            XCTAssertLessThanOrEqual(
                frame.maxY,
                layout.panelSize.height - SideDeckLayout.screenVerticalMargin,
                "\(widget) clipped at bottom"
            )
        }
    }
}

final class PanelHitRegionTests: XCTestCase {
    func testRightDockAcceptsDockAndFlyoutButPassesBackgroundThrough() {
        let bounds = CGRect(x: 0, y: 0, width: 560, height: 660)

        XCTAssertTrue(PanelHitRegion.contains(CGPoint(x: 530, y: 300), in: bounds, dockOnRight: true, flyoutOpen: false))
        XCTAssertFalse(PanelHitRegion.contains(CGPoint(x: 100, y: 300), in: bounds, dockOnRight: true, flyoutOpen: false))
        XCTAssertTrue(PanelHitRegion.contains(CGPoint(x: 200, y: 300), in: bounds, dockOnRight: true, flyoutOpen: true))
        XCTAssertFalse(PanelHitRegion.contains(CGPoint(x: 20, y: 300), in: bounds, dockOnRight: true, flyoutOpen: true))
        XCTAssertTrue(PanelHitRegion.contains(CGPoint(x: 20, y: 300), in: bounds, dockOnRight: true, flyoutOpen: true, flyoutWidth: 490))
    }

    func testCollapsedDockOnlyAcceptsTheVisibleEdgeTab() {
        let bounds = CGRect(x: 0, y: 0, width: 560, height: 660)

        XCTAssertTrue(PanelHitRegion.contains(CGPoint(x: 552, y: 330), in: bounds, dockOnRight: true, flyoutOpen: false, dockCollapsed: true))
        XCTAssertFalse(PanelHitRegion.contains(CGPoint(x: 530, y: 100), in: bounds, dockOnRight: true, flyoutOpen: false, dockCollapsed: true))
    }
}

@MainActor
final class CustomTrackingViewTests: XCTestCase {
    func testFirstClickIsAcceptedWhileAnotherAppIsActive() {
        let view = CustomTrackingView(rootView: EmptyView())

        XCTAssertTrue(view.acceptsFirstMouse(for: nil))
    }
}

final class ChecklistItemTests: XCTestCase {
    func testRelativeTimeUsesSingularUnitsAndRealDayCounts() {
        let now = Date(timeIntervalSince1970: 500_000)

        XCTAssertEqual(ChecklistItem(text: "", isDone: false, createdAt: now.addingTimeInterval(-60)).timeAgoString(relativeTo: now), "1 minute ago")
        XCTAssertEqual(ChecklistItem(text: "", isDone: false, createdAt: now.addingTimeInterval(-3_600)).timeAgoString(relativeTo: now), "1 hour ago")
        XCTAssertEqual(ChecklistItem(text: "", isDone: false, createdAt: now.addingTimeInterval(-172_800)).timeAgoString(relativeTo: now), "2 days ago")
    }
}
