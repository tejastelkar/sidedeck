import AppKit
import SwiftUI
import XCTest
@testable import SideDeck

final class SideDeckContrastTests: XCTestCase {
    func testFilledAccentControlsUseOpaqueWhiteForeground() throws {
        let color = try XCTUnwrap(
            NSColor(SideDeckTheme.filledControlForeground).usingColorSpace(.sRGB)
        )

        XCTAssertEqual(color.redComponent, 1, accuracy: 0.001)
        XCTAssertEqual(color.greenComponent, 1, accuracy: 0.001)
        XCTAssertEqual(color.blueComponent, 1, accuracy: 0.001)
        XCTAssertEqual(color.alphaComponent, 1, accuracy: 0.001)
    }
}
