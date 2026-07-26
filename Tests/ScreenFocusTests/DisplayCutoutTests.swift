// SPDX-License-Identifier: MPL-2.0

import CoreGraphics
import XCTest
@testable import ScreenFocus

final class DisplayCutoutTests: XCTestCase {
    private let screenFrame = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    private let leftArea = CGRect(x: 0, y: 1080, width: 738, height: 37)
    private let rightArea = CGRect(x: 990, y: 1080, width: 738, height: 37)

    func testCameraHousingUsesSafeAreaAndAuxiliaryRegions() {
        let cutout = DisplayCutout.cameraHousing(
            screenFrame: screenFrame,
            safeAreaTopInset: 37,
            auxiliaryTopLeftArea: leftArea,
            auxiliaryTopRightArea: rightArea,
            isBuiltIn: true
        )

        XCTAssertEqual(
            cutout?.frame,
            CGRect(x: 738, y: 1080, width: 252, height: 37)
        )
    }

    func testExternalDisplayNeverCreatesCameraHousing() {
        let cutout = DisplayCutout.cameraHousing(
            screenFrame: screenFrame,
            safeAreaTopInset: 37,
            auxiliaryTopLeftArea: leftArea,
            auxiliaryTopRightArea: rightArea,
            isBuiltIn: false
        )

        XCTAssertNil(cutout)
    }

    func testMissingSafeAreaOrAuxiliaryRegionDoesNotCreateCameraHousing() {
        XCTAssertNil(
            DisplayCutout.cameraHousing(
                screenFrame: screenFrame,
                safeAreaTopInset: 0,
                auxiliaryTopLeftArea: leftArea,
                auxiliaryTopRightArea: rightArea,
                isBuiltIn: true
            )
        )
        XCTAssertNil(
            DisplayCutout.cameraHousing(
                screenFrame: screenFrame,
                safeAreaTopInset: 37,
                auxiliaryTopLeftArea: nil,
                auxiliaryTopRightArea: rightArea,
                isBuiltIn: true
            )
        )
    }

    func testOverlappingAuxiliaryRegionsAreRejected() {
        let overlappingRightArea = CGRect(
            x: 700,
            y: 1080,
            width: 1028,
            height: 37
        )

        XCTAssertNil(
            DisplayCutout.cameraHousing(
                screenFrame: screenFrame,
                safeAreaTopInset: 37,
                auxiliaryTopLeftArea: leftArea,
                auxiliaryTopRightArea: overlappingRightArea,
                isBuiltIn: true
            )
        )
    }
}
