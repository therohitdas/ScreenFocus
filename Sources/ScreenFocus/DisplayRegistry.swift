import AppKit
import CoreGraphics
import Foundation

struct DisplayDescriptor: Equatable, Sendable {
    let id: CGDirectDisplayID
    let name: String
    let frame: CGRect
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

            return DisplayDescriptor(
                id: CGDirectDisplayID(number.uint32Value),
                name: screen.localizedName,
                frame: screen.frame
            )
        }
        return displays
    }

    func display(id: CGDirectDisplayID) -> DisplayDescriptor? {
        displays.first { $0.id == id }
    }
}
