import XCTest
@testable import SideDeck

@MainActor
final class CompletionBehaviorTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "CompletionBehaviorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testCompletionControlSizesProvideReliableHitTargets() {
        XCTAssertEqual(CompletionControlSize.compact.hitTarget, 18)
        XCTAssertEqual(CompletionControlSize.regular.hitTarget, 24)
    }

    func testNoteCompletionTogglesOnceAndPersists() {
        let state = SideDeckState(defaults: defaults, startServices: false)
        let note = ChecklistItem(text: "Verify release", isDone: false)
        state.noteLines = [note]

        state.toggleNote(note)

        XCTAssertTrue(state.noteLines[0].isDone)
        let reloaded = SideDeckState(defaults: defaults, startServices: false)
        XCTAssertTrue(reloaded.noteLines[0].isDone)
    }

    func testMissingNoteIsIgnoredWithoutMutation() {
        let state = SideDeckState(defaults: defaults, startServices: false)
        state.noteLines = [ChecklistItem(text: "Keep", isDone: false)]

        state.toggleNote(ChecklistItem(text: "Missing", isDone: false))

        XCTAssertEqual(state.noteLines.map(\.text), ["Keep"])
    }
}
