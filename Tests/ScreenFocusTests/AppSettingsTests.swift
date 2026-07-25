import Foundation
import XCTest
@testable import ScreenFocus

@MainActor
final class AppSettingsTests: XCTestCase {
    func testNewSettingsUseRecommendedFullBorderAppearance() throws {
        let suiteName = "ScreenFocusTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.highlightStyle, .fullBorder)
        XCTAssertEqual(settings.highlightColorHex, "#797979")
        XCTAssertEqual(settings.edgeGap, 0)
        XCTAssertEqual(settings.cornerLength, 72)
        XCTAssertEqual(settings.cornerThickness, 5)
        XCTAssertEqual(settings.overlayOpacity, 1)
    }

    func testRecommendedAppearanceCanBeRestored() throws {
        let suiteName = "ScreenFocusTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let settings = AppSettings(defaults: defaults)

        settings.highlightStyle = .cornerMarkers
        settings.highlightColorHex = "#FF0000"
        settings.edgeGap = 30
        settings.cornerLength = 12
        settings.resetRecommendedAppearance()

        XCTAssertEqual(settings.highlightStyle, .fullBorder)
        XCTAssertEqual(settings.highlightColorHex, "#797979")
        XCTAssertEqual(settings.edgeGap, 0)
        XCTAssertEqual(settings.cornerLength, 72)
        XCTAssertEqual(settings.cornerThickness, 5)
        XCTAssertEqual(settings.overlayOpacity, 1)
    }

    func testOverlayCanBeDisabledWithoutDisablingFocusTransfer() throws {
        let suiteName = "ScreenFocusTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let settings = AppSettings(defaults: defaults)

        settings.highlightStyle = .none

        XCTAssertEqual(settings.highlightStyle, .none)
        XCTAssertTrue(settings.enabled)
        XCTAssertTrue(settings.focusTransferEnabled)
    }
}
