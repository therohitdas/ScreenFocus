// SPDX-License-Identifier: MPL-2.0

import CoreGraphics
import XCTest
@testable import ScreenFocus

final class WindowOrderingTests: XCTestCase {
    private let displayBounds = CGRect(x: 0, y: 0, width: 1000, height: 800)

    func testTopmostOverlappingWindowPrecedesPointerWindow() throws {
        let smallTopWindow = window(
            id: 10,
            pid: 100,
            bounds: CGRect(x: 350, y: 250, width: 300, height: 250)
        )
        let largePointerWindow = window(
            id: 20,
            pid: 200,
            bounds: displayBounds
        )
        let candidates = WindowOrdering.candidates(
            from: [smallTopWindow, largePointerWindow],
            on: displayBounds,
            excludingPID: 999
        )
        let baseIndex = try XCTUnwrap(
            WindowOrdering.indexOfWindow(
                ownedBy: largePointerWindow.ownerPID,
                matching: largePointerWindow.bounds,
                in: candidates
            )
        )

        XCTAssertEqual(
            WindowOrdering.overlappingWindows(
                aboveAndIncluding: baseIndex,
                in: candidates
            ),
            [smallTopWindow, largePointerWindow]
        )
    }

    func testSeparateTopmostWindowDoesNotReplacePointerWindow() throws {
        let separateTopWindow = window(
            id: 10,
            pid: 100,
            bounds: CGRect(x: 650, y: 100, width: 300, height: 250)
        )
        let pointerWindow = window(
            id: 20,
            pid: 200,
            bounds: CGRect(x: 0, y: 100, width: 500, height: 600)
        )
        let candidates = WindowOrdering.candidates(
            from: [separateTopWindow, pointerWindow],
            on: displayBounds,
            excludingPID: 999
        )
        let baseIndex = try XCTUnwrap(
            WindowOrdering.indexOfWindow(
                ownedBy: pointerWindow.ownerPID,
                matching: pointerWindow.bounds,
                in: candidates
            )
        )

        XCTAssertEqual(
            WindowOrdering.overlappingWindows(
                aboveAndIncluding: baseIndex,
                in: candidates
            ),
            [pointerWindow]
        )
    }

    func testCandidateFilteringPreservesFrontToBackOrder() {
        let topWindow = window(
            id: 1,
            pid: 100,
            bounds: CGRect(x: 100, y: 100, width: 300, height: 300)
        )
        let overlay = window(
            id: 2,
            pid: 200,
            layer: 25,
            bounds: displayBounds
        )
        let transparentWindow = window(
            id: 3,
            pid: 300,
            bounds: displayBounds,
            alpha: 0
        )
        let otherDisplayWindow = window(
            id: 4,
            pid: 400,
            bounds: CGRect(x: 1200, y: 0, width: 500, height: 500)
        )
        let currentProcessWindow = window(
            id: 5,
            pid: 999,
            bounds: displayBounds
        )
        let lowerWindow = window(
            id: 6,
            pid: 600,
            bounds: displayBounds
        )

        XCTAssertEqual(
            WindowOrdering.candidates(
                from: [
                    topWindow,
                    overlay,
                    transparentWindow,
                    otherDisplayWindow,
                    currentProcessWindow,
                    lowerWindow
                ],
                on: displayBounds,
                excludingPID: 999
            ),
            [topWindow, lowerWindow]
        )
    }

    func testAXFrameMatchingAllowsSmallWindowServerDifferences() {
        let snapshot = window(
            id: 1,
            pid: 100,
            bounds: CGRect(x: 100, y: 100, width: 400, height: 300)
        )

        XCTAssertEqual(
            WindowOrdering.indexOfWindow(
                ownedBy: 100,
                matching: CGRect(x: 102, y: 98, width: 398, height: 304),
                in: [snapshot]
            ),
            0
        )
        XCTAssertTrue(
            WindowOrdering.framesMatch(
                snapshot.bounds,
                CGRect(x: 102, y: 98, width: 398, height: 304)
            )
        )
    }

    func testSamplePointsStayInsideVisibleDisplayIntersection() {
        let windowBounds = CGRect(x: -100, y: -50, width: 500, height: 400)
        let points = WindowOrdering.samplePoints(
            in: windowBounds,
            clippedTo: displayBounds
        )
        let visibleBounds = windowBounds.intersection(displayBounds)

        XCTAssertEqual(points.first, CGPoint(x: 200, y: 175))
        XCTAssertEqual(points.count, 9)
        XCTAssertTrue(points.allSatisfy(visibleBounds.contains))
    }

    private func window(
        id: CGWindowID,
        pid: pid_t,
        layer: Int = 0,
        bounds: CGRect,
        alpha: Double = 1
    ) -> WindowSnapshot {
        WindowSnapshot(
            id: id,
            ownerPID: pid,
            layer: layer,
            bounds: bounds,
            alpha: alpha
        )
    }
}
