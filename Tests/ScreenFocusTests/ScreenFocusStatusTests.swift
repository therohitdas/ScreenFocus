import XCTest
@testable import ScreenFocus

final class ScreenFocusStatusTests: XCTestCase {
    func testResumeRestoresAlignedStatusWhenFocusProtectionIsAvailable() {
        let status = ScreenFocusStatus.paused.reconciledWithFocusProtection(
            enabled: true,
            accessibilityGranted: true
        )

        XCTAssertEqual(status, .aligned)
    }

    func testPermissionGrantRestoresAlignedStatus() {
        let status = ScreenFocusStatus.highlightOnly.reconciledWithFocusProtection(
            enabled: true,
            accessibilityGranted: true
        )

        XCTAssertEqual(status, .aligned)
    }

    func testActiveGuardStatusSurvivesAnUnrelatedSettingsChange() {
        let status = ScreenFocusStatus.guarded.reconciledWithFocusProtection(
            enabled: true,
            accessibilityGranted: true
        )

        XCTAssertEqual(status, .guarded)
    }

    func testUnavailableFocusProtectionUsesHighlightOnlyStatus() {
        let status = ScreenFocusStatus.aligned.reconciledWithFocusProtection(
            enabled: true,
            accessibilityGranted: false
        )

        XCTAssertEqual(status, .highlightOnly)
    }
}
