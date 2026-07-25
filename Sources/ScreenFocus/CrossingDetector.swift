import CoreGraphics
import Foundation

struct DisplayCrossing: Equatable, Sendable {
    let displayID: CGDirectDisplayID
    let isInitial: Bool
}

struct CrossingDetector: Sendable {
    private(set) var currentDisplayID: CGDirectDisplayID?
    let boundaryInset: CGFloat

    init(boundaryInset: CGFloat = 6) {
        self.boundaryInset = boundaryInset
    }

    mutating func update(
        point: CGPoint,
        displays: [DisplayDescriptor],
        mouseButtonsPressed: Bool
    ) -> DisplayCrossing? {
        guard !mouseButtonsPressed else { return nil }
        guard let candidate = displays.first(where: { $0.frame.contains(point) }) else {
            return nil
        }

        if currentDisplayID == nil {
            currentDisplayID = candidate.id
            return DisplayCrossing(displayID: candidate.id, isInitial: true)
        }

        guard candidate.id != currentDisplayID else { return nil }

        let stableFrame = candidate.frame.insetBy(dx: boundaryInset, dy: boundaryInset)
        guard stableFrame.width > 0, stableFrame.height > 0, stableFrame.contains(point) else {
            return nil
        }

        currentDisplayID = candidate.id
        return DisplayCrossing(displayID: candidate.id, isInitial: false)
    }

    mutating func reset() {
        currentDisplayID = nil
    }
}
