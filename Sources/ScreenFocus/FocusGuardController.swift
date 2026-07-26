// SPDX-License-Identifier: MPL-2.0

import AppKit
import CoreGraphics
import Foundation

@MainActor
final class FocusGuardController {
    private let panel = FocusGuardPanel()
    private let sinkView = KeySinkView()
    private(set) var isEngaged = false

    init() {
        panel.contentView = sinkView
        panel.makeFirstResponder(sinkView)
    }

    @discardableResult
    func engage(on display: DisplayDescriptor) -> Bool {
        let origin = CGPoint(x: display.frame.minX + 1, y: display.frame.minY + 1)
        panel.setFrame(
            CGRect(origin: origin, size: CGSize(width: 2, height: 2)),
            display: false
        )
        panel.orderFrontRegardless()

        let activated = NSRunningApplication.current.activate(options: [])
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(sinkView)
        isEngaged = activated || NSRunningApplication.current.isActive
        return isEngaged
    }

    func disengage() {
        panel.orderOut(nil)
        isEngaged = false
    }
}

@MainActor
private final class FocusGuardPanel: NSPanel {
    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 2, height: 2),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        isOpaque = false
        alphaValue = 0.01
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .statusBar
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        setAccessibilityElement(true)
        setAccessibilityLabel("ScreenFocus keyboard guard")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class KeySinkView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Intentionally absorb only keys that reached the frontmost app.
        // System-wide and third-party global shortcuts are handled earlier.
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        true
    }
}
