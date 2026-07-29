// SPDX-License-Identifier: MPL-2.0

import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
final class AccessibilityClient {
    struct Target {
        let pid: pid_t
        let application: NSRunningApplication
        let applicationElement: AXUIElement
        let windowElement: AXUIElement
    }

    private let excludedBundleIdentifiers: Set<String> = [
        "com.apple.controlcenter",
        "com.apple.dock",
        "com.apple.notificationcenterui",
        "com.apple.systemuiserver",
        "com.apple.WindowManager"
    ]

    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func requestPermission() -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func target(at quartzPoint: CGPoint, on display: DisplayDescriptor) -> Target? {
        guard let pointerTarget = hitTarget(at: quartzPoint) else { return nil }
        guard let pointerWindowFrame = frame(of: pointerTarget.windowElement) else {
            return pointerTarget
        }

        let displayBounds = CGDisplayBounds(display.id)
        let candidates = WindowOrdering.candidates(
            from: windowSnapshots(),
            on: displayBounds,
            excludingPID: ProcessInfo.processInfo.processIdentifier
        )
        guard let baseIndex = WindowOrdering.indexOfWindow(
            ownedBy: pointerTarget.pid,
            matching: pointerWindowFrame,
            in: candidates
        ) else {
            return pointerTarget
        }

        let overlappingWindows = WindowOrdering.overlappingWindows(
            aboveAndIncluding: baseIndex,
            in: candidates
        )
        for window in overlappingWindows {
            if window.id == candidates[baseIndex].id {
                return pointerTarget
            }

            for samplePoint in WindowOrdering.samplePoints(
                in: window.bounds,
                clippedTo: displayBounds
            ) {
                guard
                    let candidateTarget = hitTarget(at: samplePoint),
                    candidateTarget.pid == window.ownerPID,
                    let candidateFrame = frame(of: candidateTarget.windowElement),
                    WindowOrdering.framesMatch(candidateFrame, window.bounds)
                else {
                    continue
                }
                return candidateTarget
            }
        }

        return pointerTarget
    }

    private func hitTarget(at quartzPoint: CGPoint) -> Target? {
        guard isTrusted else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        var hitElement: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(
            systemWide,
            Float(quartzPoint.x),
            Float(quartzPoint.y),
            &hitElement
        )

        guard result == .success, let hitElement else { return nil }

        var pid: pid_t = 0
        guard AXUIElementGetPid(hitElement, &pid) == .success else { return nil }
        guard let runningApplication = eligibleApplication(pid: pid) else { return nil }

        guard let window = containingWindow(from: hitElement) else { return nil }

        let applicationElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(applicationElement, 0.25)

        return Target(
            pid: pid,
            application: runningApplication,
            applicationElement: applicationElement,
            windowElement: window
        )
    }

    private func eligibleApplication(pid: pid_t) -> NSRunningApplication? {
        guard pid != ProcessInfo.processInfo.processIdentifier else { return nil }
        guard let application = NSRunningApplication(processIdentifier: pid) else {
            return nil
        }
        guard application.activationPolicy != .prohibited else { return nil }
        if let bundleIdentifier = application.bundleIdentifier,
           excludedBundleIdentifiers.contains(bundleIdentifier) {
            return nil
        }
        return application
    }

    func focus(_ target: Target) -> Bool {
        if NSRunningApplication.current.isActive {
            NSApp.yieldActivation(to: target.application)
        }

        let activated = target.application.activate(options: [])
        _ = AXUIElementPerformAction(
            target.windowElement,
            kAXRaiseAction as CFString
        )

        var settable = DarwinBoolean(false)
        let canSetFocusedWindow = AXUIElementIsAttributeSettable(
            target.applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &settable
        ) == .success && settable.boolValue

        if canSetFocusedWindow {
            _ = AXUIElementSetAttributeValue(
                target.applicationElement,
                kAXFocusedWindowAttribute as CFString,
                target.windowElement
            )
        }

        return activated || target.application.isActive
    }

    func verify(_ target: Target) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid else {
            return false
        }

        guard let focusedWindow = copyElement(
            from: target.applicationElement,
            attribute: kAXFocusedWindowAttribute as String
        ) else {
            // Some apps expose activation correctly but not a readable focused-window attribute.
            return target.application.isActive
        }

        return CFEqual(focusedWindow, target.windowElement)
    }

    private func containingWindow(from element: AXUIElement) -> AXUIElement? {
        if copyString(from: element, attribute: kAXRoleAttribute as String) == kAXWindowRole {
            return element
        }

        if let directWindow = copyElement(
            from: element,
            attribute: kAXWindowAttribute as String
        ) {
            return directWindow
        }

        var current = element
        for _ in 0..<12 {
            guard let parent = copyElement(
                from: current,
                attribute: kAXParentAttribute as String
            ) else {
                return nil
            }

            if copyString(from: parent, attribute: kAXRoleAttribute as String) == kAXWindowRole {
                return parent
            }
            current = parent
        }

        return nil
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard
            let position = copyPoint(
                from: window,
                attribute: kAXPositionAttribute as String
            ),
            let size = copySize(
                from: window,
                attribute: kAXSizeAttribute as String
            ),
            size.width > 0,
            size.height > 0
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func windowSnapshots() -> [WindowSnapshot] {
        let options: CGWindowListOption = [
            .optionOnScreenOnly,
            .excludeDesktopElements
        ]
        guard
            let windowInfo = CGWindowListCopyWindowInfo(
                options,
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return []
        }

        return windowInfo.compactMap { information in
            guard
                let id = (information[kCGWindowNumber as String] as? NSNumber)?
                    .uint32Value,
                let ownerPID = (
                    information[kCGWindowOwnerPID as String] as? NSNumber
                )?.int32Value,
                let layer = (information[kCGWindowLayer as String] as? NSNumber)?
                    .intValue,
                let alpha = (information[kCGWindowAlpha as String] as? NSNumber)?
                    .doubleValue,
                let boundsDictionary = information[
                    kCGWindowBounds as String
                ] as? NSDictionary,
                let bounds = CGRect(
                    dictionaryRepresentation: boundsDictionary as CFDictionary
                )
            else {
                return nil
            }

            return WindowSnapshot(
                id: id,
                ownerPID: ownerPID,
                layer: layer,
                bounds: bounds,
                alpha: alpha
            )
        }
    }

    private func copyElement(from element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success, let value else {
            return nil
        }

        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func copyString(from element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        return value as? String
    }

    private func copyPoint(
        from element: AXUIElement,
        attribute: String
    ) -> CGPoint? {
        guard let value = copyAXValue(from: element, attribute: attribute) else {
            return nil
        }
        guard AXValueGetType(value) == .cgPoint else { return nil }

        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private func copySize(
        from element: AXUIElement,
        attribute: String
    ) -> CGSize? {
        guard let value = copyAXValue(from: element, attribute: attribute) else {
            return nil
        }
        guard AXValueGetType(value) == .cgSize else { return nil }

        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }

    private func copyAXValue(
        from element: AXUIElement,
        attribute: String
    ) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success, let value else {
            return nil
        }

        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }
}
