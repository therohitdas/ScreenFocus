// SPDX-License-Identifier: MPL-2.0

import AppKit
import XCTest
@testable import ScreenFocus

final class ColorParsingTests: XCTestCase {
    func testHexColorRoundTrip() throws {
        let color = try XCTUnwrap(NSColor(screenFocusHex: "#2F80ED"))
        XCTAssertEqual(color.screenFocusHex, "#2F80ED")
    }

    func testInvalidHexReturnsNil() {
        XCTAssertNil(NSColor(screenFocusHex: "not-a-color"))
        XCTAssertNil(NSColor(screenFocusHex: "#FFF"))
    }
}
