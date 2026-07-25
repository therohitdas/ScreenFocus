import AppKit
import Foundation

@MainActor
final class PointerMonitor {
    private let displayRegistry: DisplayRegistry
    private var detector = CrossingDetector()
    private var timer: Timer?
    private let onCrossing: (DisplayCrossing, CGPoint) -> Void

    init(
        displayRegistry: DisplayRegistry,
        onCrossing: @escaping (DisplayCrossing, CGPoint) -> Void
    ) {
        self.displayRegistry = displayRegistry
        self.onCrossing = onCrossing
    }

    func start() {
        guard timer == nil else { return }

        let newTimer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sample()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
        sample()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        detector.reset()
        sample()
    }

    private func sample() {
        let point = NSEvent.mouseLocation
        let crossing = detector.update(
            point: point,
            displays: displayRegistry.displays,
            mouseButtonsPressed: NSEvent.pressedMouseButtons != 0
        )

        if let crossing {
            onCrossing(crossing, point)
        }
    }
}
