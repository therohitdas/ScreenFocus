import XCTest
@testable import ScreenFocus

final class ScreenFocusStatusTests: XCTestCase {
    func testTwoDisplaysAreActiveByDefault() {
        let availability = ScreenFocusAvailability.resolve(
            enabled: true,
            pauseOnSingleDisplay: true,
            displayCount: 2
        )

        XCTAssertEqual(availability, .active)
    }

    func testOneDisplayAutomaticallyDisablesScreenFocus() {
        let availability = ScreenFocusAvailability.resolve(
            enabled: true,
            pauseOnSingleDisplay: true,
            displayCount: 1
        )

        XCTAssertEqual(availability, .singleDisplay)
        XCTAssertEqual(availability.disabledReason, "One display")
    }

    func testSingleDisplayPauseCanBeTurnedOff() {
        let availability = ScreenFocusAvailability.resolve(
            enabled: true,
            pauseOnSingleDisplay: false,
            displayCount: 1
        )

        XCTAssertEqual(availability, .active)
    }

    func testManualPauseTakesPriority() {
        let availability = ScreenFocusAvailability.resolve(
            enabled: false,
            pauseOnSingleDisplay: true,
            displayCount: 1
        )

        XCTAssertEqual(availability, .paused)
        XCTAssertEqual(availability.disabledReason, "Paused")
    }

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
