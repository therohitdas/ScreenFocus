// SPDX-License-Identifier: MPL-2.0

import CoreGraphics
import Foundation

struct WindowSnapshot: Equatable, Sendable {
    let id: CGWindowID
    let ownerPID: pid_t
    let layer: Int
    let bounds: CGRect
    let alpha: Double
}

struct WindowOrdering {
    private static let minimumVisibleDimension: CGFloat = 24
    private static let frameMatchTolerance: CGFloat = 12

    static func candidates(
        from windows: [WindowSnapshot],
        on displayBounds: CGRect,
        excludingPID: pid_t
    ) -> [WindowSnapshot] {
        windows.filter { window in
            guard
                window.ownerPID != excludingPID,
                window.layer == 0,
                window.alpha > 0.01,
                window.bounds.width > 0,
                window.bounds.height > 0
            else {
                return false
            }

            let visibleBounds = window.bounds.intersection(displayBounds)
            return !visibleBounds.isNull
                && visibleBounds.width >= minimumVisibleDimension
                && visibleBounds.height >= minimumVisibleDimension
        }
    }

    static func indexOfWindow(
        ownedBy pid: pid_t,
        matching frame: CGRect,
        in windows: [WindowSnapshot]
    ) -> Int? {
        windows.enumerated()
            .filter { $0.element.ownerPID == pid }
            .map { index, window in
                (index, frameDistance(window.bounds, frame))
            }
            .filter { $0.1 <= frameMatchTolerance }
            .min { $0.1 < $1.1 }?
            .0
    }

    static func framesMatch(_ first: CGRect, _ second: CGRect) -> Bool {
        frameDistance(first, second) <= frameMatchTolerance
    }

    static func overlappingWindows(
        aboveAndIncluding baseIndex: Int,
        in windows: [WindowSnapshot]
    ) -> [WindowSnapshot] {
        guard windows.indices.contains(baseIndex) else { return [] }

        let baseBounds = windows[baseIndex].bounds
        return windows[...baseIndex].filter { window in
            let overlap = window.bounds.intersection(baseBounds)
            return !overlap.isNull && overlap.width > 0 && overlap.height > 0
        }
    }

    static func samplePoints(
        in windowBounds: CGRect,
        clippedTo displayBounds: CGRect
    ) -> [CGPoint] {
        let visibleBounds = windowBounds.intersection(displayBounds)
        guard
            !visibleBounds.isNull,
            visibleBounds.width > 0,
            visibleBounds.height > 0
        else {
            return []
        }

        let horizontalInset = min(16, visibleBounds.width / 4)
        let verticalInset = min(16, visibleBounds.height / 4)
        let left = visibleBounds.minX + horizontalInset
        let centerX = visibleBounds.midX
        let right = visibleBounds.maxX - horizontalInset
        let top = visibleBounds.minY + verticalInset
        let centerY = visibleBounds.midY
        let bottom = visibleBounds.maxY - verticalInset

        return [
            CGPoint(x: centerX, y: centerY),
            CGPoint(x: left, y: top),
            CGPoint(x: right, y: top),
            CGPoint(x: left, y: bottom),
            CGPoint(x: right, y: bottom),
            CGPoint(x: centerX, y: top),
            CGPoint(x: centerX, y: bottom),
            CGPoint(x: left, y: centerY),
            CGPoint(x: right, y: centerY)
        ]
    }

    private static func frameDistance(_ first: CGRect, _ second: CGRect) -> CGFloat {
        max(
            abs(first.minX - second.minX),
            abs(first.minY - second.minY),
            abs(first.width - second.width),
            abs(first.height - second.height)
        )
    }
}
