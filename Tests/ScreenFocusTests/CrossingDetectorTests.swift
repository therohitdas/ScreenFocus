import CoreGraphics
import XCTest
@testable import ScreenFocus

final class CrossingDetectorTests: XCTestCase {
    private let displays = [
        DisplayDescriptor(
            id: 1,
            name: "Display 1",
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800)
        ),
        DisplayDescriptor(
            id: 2,
            name: "Display 2",
            frame: CGRect(x: 1000, y: 0, width: 1000, height: 800)
        )
    ]

    func testFirstSamplePrimesWithoutARealCrossing() {
        var detector = CrossingDetector()

        let event = detector.update(
            point: CGPoint(x: 500, y: 400),
            displays: displays,
            mouseButtonsPressed: false
        )

        XCTAssertEqual(event, DisplayCrossing(displayID: 1, isInitial: true))
    }

    func testCrossingRequiresPointerInsideBoundaryInset() {
        var detector = CrossingDetector(boundaryInset: 6)
        _ = detector.update(
            point: CGPoint(x: 500, y: 400),
            displays: displays,
            mouseButtonsPressed: false
        )

        XCTAssertNil(detector.update(
            point: CGPoint(x: 1002, y: 400),
            displays: displays,
            mouseButtonsPressed: false
        ))

        XCTAssertEqual(
            detector.update(
                point: CGPoint(x: 1010, y: 400),
                displays: displays,
                mouseButtonsPressed: false
            ),
            DisplayCrossing(displayID: 2, isInitial: false)
        )
    }

    func testCrossingIsDeferredWhileDragging() {
        var detector = CrossingDetector()
        _ = detector.update(
            point: CGPoint(x: 500, y: 400),
            displays: displays,
            mouseButtonsPressed: false
        )

        XCTAssertNil(detector.update(
            point: CGPoint(x: 1200, y: 400),
            displays: displays,
            mouseButtonsPressed: true
        ))

        XCTAssertEqual(
            detector.update(
                point: CGPoint(x: 1200, y: 400),
                displays: displays,
                mouseButtonsPressed: false
            ),
            DisplayCrossing(displayID: 2, isInitial: false)
        )
    }

    func testMovingWithinSameDisplayDoesNotEmitAnotherEvent() {
        var detector = CrossingDetector()
        _ = detector.update(
            point: CGPoint(x: 500, y: 400),
            displays: displays,
            mouseButtonsPressed: false
        )

        XCTAssertNil(detector.update(
            point: CGPoint(x: 700, y: 200),
            displays: displays,
            mouseButtonsPressed: false
        ))
    }
}
