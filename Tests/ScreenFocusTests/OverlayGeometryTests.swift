// SPDX-License-Identifier: MPL-2.0

import CoreGraphics
import XCTest
@testable import ScreenFocus

final class OverlayGeometryTests: XCTestCase {
    private let displayFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    func testFullBorderEdgesMeetWithoutOverlapping() {
        let frames = Dictionary(
            uniqueKeysWithValues: BorderEdge.allCases.map { edge in
                (
                    edge,
                    BorderGeometry.frame(
                        for: edge,
                        displayFrame: displayFrame,
                        gap: 0,
                        thickness: 5
                    )
                )
            }
        )

        XCTAssertEqual(overlapArea(frames[.top]!, frames[.left]!), 0)
        XCTAssertEqual(overlapArea(frames[.top]!, frames[.right]!), 0)
        XCTAssertEqual(overlapArea(frames[.bottom]!, frames[.left]!), 0)
        XCTAssertEqual(overlapArea(frames[.bottom]!, frames[.right]!), 0)
    }

    func testFullBorderCoversExactlyOnePerimeterLayer() {
        let frames = BorderEdge.allCases.map {
            BorderGeometry.frame(
                for: $0,
                displayFrame: displayFrame,
                gap: 8,
                thickness: 5
            )
        }
        let paintedArea = frames.reduce(0) { area, frame in
            area + (frame.width * frame.height)
        }

        let innerFrame = displayFrame.insetBy(dx: 8, dy: 8)
        let center = innerFrame.insetBy(dx: 5, dy: 5)
        let expectedArea = (innerFrame.width * innerFrame.height)
            - (center.width * center.height)

        XCTAssertEqual(paintedArea, expectedArea)
    }

    func testCornerMarkerSegmentsDoNotDoublePaintTheirJoint() {
        let bounds = CGRect(x: 0, y: 0, width: 72, height: 72)

        for corner in CornerPosition.allCases {
            let rectangles = CornerGeometry.rectangles(
                for: corner,
                bounds: bounds,
                thickness: 5
            )

            XCTAssertEqual(
                overlapArea(rectangles.horizontal, rectangles.vertical),
                0,
                "\(corner) contains an overlapping alpha region"
            )
        }
    }

    func testTopBorderRemainsStraightWithoutACutout() {
        let layout = TopBorderGeometry.layout(
            displayFrame: displayFrame,
            cutoutFrame: nil,
            gap: 0,
            thickness: 5
        )

        XCTAssertEqual(
            layout.frame,
            BorderGeometry.frame(
                for: .top,
                displayFrame: displayFrame,
                gap: 0,
                thickness: 5
            )
        )
        XCTAssertNil(layout.cutoutRoute)
    }

    func testTopBorderRoutesAroundCutoutWithRoundedCorners() throws {
        let cutout = CGRect(x: 832, y: 1006, width: 256, height: 74)
        let layout = TopBorderGeometry.layout(
            displayFrame: displayFrame,
            cutoutFrame: cutout,
            gap: 0,
            thickness: 5
        )
        let route = try XCTUnwrap(layout.cutoutRoute)

        XCTAssertLessThan(layout.frame.minY, cutout.minY)
        XCTAssertLessThan(route.leftX + layout.frame.minX, cutout.minX)
        XCTAssertGreaterThan(route.rightX + layout.frame.minX, cutout.maxX)
        XCTAssertLessThan(route.bottomY + layout.frame.minY, cutout.minY)
        XCTAssertGreaterThan(route.cornerRadius, 0)
        XCTAssertLessThanOrEqual(route.cornerRadius, 12)
    }

    func testNotchContourRoundsAllFourTurns() throws {
        let layout = TopBorderGeometry.layout(
            displayFrame: displayFrame,
            cutoutFrame: CGRect(x: 832, y: 1006, width: 256, height: 74),
            gap: 0,
            thickness: 5
        )
        let path = try XCTUnwrap(
            TopBorderGeometry.path(
                for: layout,
                bounds: CGRect(origin: .zero, size: layout.frame.size)
            )
        )
        var quadraticCurveCount = 0

        path.applyWithBlock { element in
            if element.pointee.type == .addQuadCurveToPoint {
                quadraticCurveCount += 1
            }
        }

        XCTAssertEqual(quadraticCurveCount, 4)
    }

    func testTopBorderDoesNotRouteWhenEdgeGapClearsCutout() {
        let cutout = CGRect(x: 832, y: 1006, width: 256, height: 74)
        let layout = TopBorderGeometry.layout(
            displayFrame: displayFrame,
            cutoutFrame: cutout,
            gap: 80,
            thickness: 5
        )

        XCTAssertNil(layout.cutoutRoute)
    }

    func testBuiltInBorderRoundsAllFourOuterCorners() {
        let layout = BuiltInBorderGeometry.layout(
            displayFrame: displayFrame,
            cutoutFrame: nil,
            gap: 0,
            thickness: 5
        )
        let path = BuiltInBorderGeometry.path(for: layout)
        let elementCounts = pathElementCounts(path)

        XCTAssertEqual(layout.frame, displayFrame)
        XCTAssertEqual(
            layout.perimeter,
            CGRect(x: 2.5, y: 2.5, width: 1915, height: 1075)
        )
        XCTAssertEqual(
            layout.cornerRadius,
            BuiltInBorderGeometry.recommendedCornerRadius
        )
        XCTAssertNil(layout.cutoutRoute)
        XCTAssertEqual(elementCounts.quadraticCurves, 4)
        XCTAssertEqual(elementCounts.closedSubpaths, 1)
    }

    func testBuiltInBorderCombinesRoundedCornersAndNotchRoute() {
        let layout = BuiltInBorderGeometry.layout(
            displayFrame: displayFrame,
            cutoutFrame: CGRect(x: 832, y: 1006, width: 256, height: 74),
            gap: 0,
            thickness: 5
        )
        let path = BuiltInBorderGeometry.path(for: layout)
        let elementCounts = pathElementCounts(path)

        XCTAssertNotNil(layout.cutoutRoute)
        XCTAssertEqual(elementCounts.quadraticCurves, 8)
        XCTAssertEqual(elementCounts.closedSubpaths, 1)
    }

    private func overlapArea(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let intersection = first.intersection(second)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }

    private func pathElementCounts(
        _ path: CGPath
    ) -> (quadraticCurves: Int, closedSubpaths: Int) {
        var quadraticCurveCount = 0
        var closedSubpathCount = 0

        path.applyWithBlock { element in
            switch element.pointee.type {
            case .addQuadCurveToPoint:
                quadraticCurveCount += 1
            case .closeSubpath:
                closedSubpathCount += 1
            default:
                break
            }
        }

        return (quadraticCurveCount, closedSubpathCount)
    }
}
