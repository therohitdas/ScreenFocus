// SPDX-License-Identifier: MPL-2.0

import AppKit
import CoreGraphics
import Foundation

struct DisplayCutout: Equatable, Sendable {
    let frame: CGRect

    static func cameraHousing(
        screenFrame: CGRect,
        safeAreaTopInset: CGFloat,
        auxiliaryTopLeftArea: CGRect?,
        auxiliaryTopRightArea: CGRect?,
        isBuiltIn: Bool
    ) -> DisplayCutout? {
        guard
            isBuiltIn,
            safeAreaTopInset > 0,
            let leftArea = auxiliaryTopLeftArea,
            let rightArea = auxiliaryTopRightArea,
            rightArea.minX > leftArea.maxX
        else {
            return nil
        }

        let frame = CGRect(
            x: leftArea.maxX,
            y: screenFrame.maxY - safeAreaTopInset,
            width: rightArea.minX - leftArea.maxX,
            height: safeAreaTopInset
        ).intersection(screenFrame)

        guard !frame.isNull, frame.width > 0, frame.height > 0 else {
            return nil
        }

        return DisplayCutout(frame: frame)
    }
}

struct DisplayDescriptor: Equatable, Sendable {
    let id: CGDirectDisplayID
    let name: String
    let frame: CGRect
    let isBuiltIn: Bool
    let cutout: DisplayCutout?

    init(
        id: CGDirectDisplayID,
        name: String,
        frame: CGRect,
        isBuiltIn: Bool = false,
        cutout: DisplayCutout? = nil
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.isBuiltIn = isBuiltIn
        self.cutout = cutout
    }
}

@MainActor
final class DisplayRegistry {
    private(set) var displays: [DisplayDescriptor] = []

    init() {
        refresh()
    }

    @discardableResult
    func refresh() -> [DisplayDescriptor] {
        displays = NSScreen.screens.compactMap { screen in
            guard
                let number = screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                ] as? NSNumber
            else {
                return nil
            }

            let displayID = CGDirectDisplayID(number.uint32Value)
            let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
            let cutout = DisplayCutout.cameraHousing(
                screenFrame: screen.frame,
                safeAreaTopInset: screen.safeAreaInsets.top,
                auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
                auxiliaryTopRightArea: screen.auxiliaryTopRightArea,
                isBuiltIn: isBuiltIn
            )

            return DisplayDescriptor(
                id: displayID,
                name: screen.localizedName,
                frame: screen.frame,
                isBuiltIn: isBuiltIn,
                cutout: cutout
            )
        }
        return displays
    }

    func display(id: CGDirectDisplayID) -> DisplayDescriptor? {
        displays.first { $0.id == id }
    }
}
