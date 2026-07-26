// SPDX-License-Identifier: MPL-2.0

import AppKit
import CoreGraphics
import Foundation
import ServiceManagement

enum ScreenFocusAvailability: Equatable {
    case active
    case paused
    case singleDisplay

    static func resolve(
        enabled: Bool,
        pauseOnSingleDisplay: Bool,
        displayCount: Int
    ) -> ScreenFocusAvailability {
        guard enabled else { return .paused }
        guard !pauseOnSingleDisplay || displayCount > 1 else {
            return .singleDisplay
        }
        return .active
    }

    var isActive: Bool {
        self == .active
    }

    var disabledReason: String? {
        switch self {
        case .active:
            nil
        case .paused:
            "Paused"
        case .singleDisplay:
            "One display"
        }
    }
}

enum ScreenFocusStatus: Equatable {
    case starting
    case aligned
    case transitioning
    case guarded
    case failed(String)
    case highlightOnly
    case paused

    var title: String {
        switch self {
        case .starting:
            "Starting"
        case .aligned:
            "Aligned"
        case .transitioning:
            "Switching focus"
        case .guarded:
            "Guarded — no target window"
        case .failed:
            "Focus could not be protected"
        case .highlightOnly:
            "Highlight only"
        case .paused:
            "Paused"
        }
    }

    var symbolName: String {
        switch self {
        case .guarded, .transitioning:
            "cursorarrow.rays"
        case .failed:
            "exclamationmark.triangle.fill"
        case .highlightOnly:
            "lock.open.fill"
        case .paused:
            "pause.circle"
        default:
            "viewfinder"
        }
    }

    func reconciledWithFocusProtection(
        enabled: Bool,
        accessibilityGranted: Bool
    ) -> ScreenFocusStatus {
        guard enabled, accessibilityGranted else {
            return .highlightOnly
        }

        switch self {
        case .starting, .highlightOnly, .paused:
            return .aligned
        case .aligned, .transitioning, .guarded, .failed:
            return self
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var status: ScreenFocusStatus = .starting
    @Published private(set) var pointerDisplayName = "Unknown"
    @Published private(set) var connectedDisplayCount = 0
    @Published private(set) var lastError: String?
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var launchAtLoginError: String?

    let settings: AppSettings

    private let displayRegistry = DisplayRegistry()
    private let overlays = OverlayController()
    private let accessibility = AccessibilityClient()
    private let focusGuard = FocusGuardController()
    private var transitionID = 0
    private var currentDisplayID: CGDirectDisplayID?
    private var displayObserver: NSObjectProtocol?
    private var permissionTimer: Timer?

    private lazy var pointerMonitor = PointerMonitor(
        displayRegistry: displayRegistry
    ) { [weak self] crossing, appKitPoint in
        self?.handle(crossing: crossing, appKitPoint: appKitPoint)
    }

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        connectedDisplayCount = displayRegistry.displays.count
        accessibilityGranted = accessibility.isTrusted
        self.settings.onChange = { [weak self] in
            self?.settingsDidChange()
        }

        overlays.rebuild(displays: displayRegistry.displays, settings: settings)

        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.displaysDidChange()
            }
        }

        pointerMonitor.start()
        startPermissionMonitoring()
        reconcileLaunchAtLogin()

        if availability.isActive,
           settings.focusTransferEnabled,
           !accessibilityGranted {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                self?.requestAccessibilityPermission()
            }
        }
    }

    func requestAccessibilityPermission() {
        _ = accessibility.requestPermission()
        refreshPermissionStatus()
    }

    func refreshPermissionStatus() {
        updateAccessibilityStatus()
    }

    func toggleEnabled() {
        settings.enabled.toggle()
    }

    var availability: ScreenFocusAvailability {
        ScreenFocusAvailability.resolve(
            enabled: settings.enabled,
            pauseOnSingleDisplay: settings.pauseOnSingleDisplay,
            displayCount: connectedDisplayCount
        )
    }

    var trayStatusTitle: String {
        if let reason = availability.disabledReason {
            return "Disabled — \(reason)"
        }
        if !settings.focusTransferEnabled {
            return "Active — Highlight only"
        }
        if !accessibilityGranted {
            return "Active — Needs accessibility"
        }
        return "Active"
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if !launchAtLoginIsRequested {
                    try SMAppService.mainApp.register()
                }
            } else {
                if launchAtLoginIsRequested {
                    try SMAppService.mainApp.unregister()
                }
            }
            settings.launchAtLogin = enabled && launchAtLoginIsRequested
            launchAtLoginError = nil
        } catch {
            settings.launchAtLogin = launchAtLoginIsRequested
            launchAtLoginError =
                "Launch at login could not be changed: \(error.localizedDescription)"
        }
    }

    func refreshLaunchAtLoginStatus() {
        settings.launchAtLogin = launchAtLoginIsRequested
    }

    private var launchAtLoginIsRequested: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            true
        case .notRegistered, .notFound:
            false
        @unknown default:
            false
        }
    }

    private func reconcileLaunchAtLogin() {
        if settings.shouldRegisterLaunchAtLoginByDefault {
            setLaunchAtLogin(true)
        } else {
            settings.launchAtLogin = launchAtLoginIsRequested
        }
    }

    private func settingsDidChange() {
        overlays.refreshLayout()

        guard availability.isActive else {
            transitionID += 1
            focusGuard.disengage()
            overlays.hideAll()
            status = .paused
            return
        }

        status = status.reconciledWithFocusProtection(
            enabled: settings.focusTransferEnabled,
            accessibilityGranted: accessibilityGranted
        )

        if status == .highlightOnly {
            focusGuard.disengage()
        }

        if let currentDisplayID {
            overlays.show(displayID: currentDisplayID, style: .aligned)
        }
    }

    private func displaysDidChange() {
        transitionID += 1
        focusGuard.disengage()
        let displays = displayRegistry.refresh()
        connectedDisplayCount = displays.count
        overlays.rebuild(displays: displays, settings: settings)
        pointerMonitor.reset()
        settingsDidChange()
    }

    private func handle(crossing: DisplayCrossing, appKitPoint: CGPoint) {
        guard let display = displayRegistry.display(id: crossing.displayID) else { return }

        currentDisplayID = crossing.displayID
        pointerDisplayName = display.name

        guard availability.isActive else {
            status = .paused
            overlays.hideAll()
            return
        }

        if crossing.isInitial {
            status = accessibilityGranted && settings.focusTransferEnabled
                ? .aligned
                : .highlightOnly
            overlays.show(displayID: crossing.displayID, style: .aligned)
            return
        }

        guard settings.focusTransferEnabled, accessibilityGranted else {
            focusGuard.disengage()
            status = .highlightOnly
            overlays.show(displayID: crossing.displayID, style: .aligned)
            return
        }

        transitionID += 1
        let thisTransition = transitionID
        status = .transitioning
        lastError = nil
        overlays.show(displayID: crossing.displayID, style: .aligned)

        let quartzPoint = CGEvent(source: nil)?.location ?? appKitPoint
        guard let target = accessibility.target(at: quartzPoint) else {
            engageGuard(on: display)
            return
        }

        let requested = accessibility.focus(target)
        guard requested else {
            engageGuard(on: display)
            return
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self, thisTransition == self.transitionID else { return }

            if self.accessibility.verify(target) {
                self.focusGuard.disengage()
                self.status = .aligned
                self.overlays.show(displayID: display.id, style: .aligned)
            } else {
                self.engageGuard(on: display)
            }
        }
    }

    private func engageGuard(on display: DisplayDescriptor) {
        if focusGuard.engage(on: display) {
            status = .guarded
            overlays.show(displayID: display.id, style: .guarded)
        } else {
            status = .failed("macOS did not grant focus to the target or ScreenFocus.")
            lastError = "Keyboard focus may still be on the previous display."
            overlays.show(displayID: display.id, style: .failed)
        }
    }

    private func startPermissionMonitoring() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateAccessibilityStatus()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    private func updateAccessibilityStatus() {
        let granted = accessibility.isTrusted
        guard granted != accessibilityGranted else { return }

        accessibilityGranted = granted
        settingsDidChange()
    }
}
