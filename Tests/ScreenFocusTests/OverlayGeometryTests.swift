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

    private func overlapArea(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let intersection = first.intersection(second)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}
