import XCTest
@testable import SideDeck

final class SideDeckSymbolTests: XCTestCase {
    func testWiFiUsesTheStandardApplePlatformSymbol() {
        XCTAssertEqual(SideDeckSymbols.wifi, "wifi")
    }
}
