// SPDX-License-Identifier: MPL-2.0

import AppKit
import XCTest
@testable import ScreenFocus

@MainActor
final class SettingsWindowPolicyTests: XCTestCase {
    func testSettingsWindowFloatsAndRemainsVisibleWhenAppDeactivates() {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 460, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        SettingsWindowPolicy.apply(to: window)

        XCTAssertEqual(window.level, .floating)
        XCTAssertFalse(window.hidesOnDeactivate)
        XCTAssertTrue(window.collectionBehavior.contains(.moveToActiveSpace))
    }
}
