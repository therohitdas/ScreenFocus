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

    func target(at quartzPoint: CGPoint) -> Target? {
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
        guard pid != ProcessInfo.processInfo.processIdentifier else { return nil }

        guard let runningApplication = NSRunningApplication(processIdentifier: pid) else {
            return nil
        }

        guard runningApplication.activationPolicy != .prohibited else { return nil }
        if let bundleIdentifier = runningApplication.bundleIdentifier,
           excludedBundleIdentifiers.contains(bundleIdentifier) {
            return nil
        }

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
}
