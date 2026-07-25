import AppKit
import Combine
import Foundation

enum HighlightStyle: String, CaseIterable, Identifiable {
    case fullBorder
    case cornerMarkers
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullBorder:
            "Full border"
        case .cornerMarkers:
            "Corner markers"
        case .none:
            "Off"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let enabled = "enabled"
        static let focusTransferEnabled = "focusTransferEnabled"
        static let highlightStyle = "highlightStyle"
        static let highlightColorHex = "highlightColorHex"
        static let edgeGap = "edgeGap"
        static let cornerLength = "cornerLength"
        static let cornerThickness = "cornerThickness"
        static let overlayOpacity = "overlayOpacity"
        static let launchAtLogin = "launchAtLogin"
    }

    private let defaults: UserDefaults
    private var isLoading = true
    private var isSaving = false

    let shouldRegisterLaunchAtLoginByDefault: Bool

    var onChange: (() -> Void)?

    @Published var enabled: Bool {
        didSet { changed() }
    }

    @Published var focusTransferEnabled: Bool {
        didSet { changed() }
    }

    @Published var highlightStyle: HighlightStyle {
        didSet { changed() }
    }

    @Published var highlightColorHex: String {
        didSet { changed() }
    }

    @Published var edgeGap: Double {
        didSet { changed() }
    }

    @Published var cornerLength: Double {
        didSet { changed() }
    }

    @Published var cornerThickness: Double {
        didSet { changed() }
    }

    @Published var overlayOpacity: Double {
        didSet { changed() }
    }

    @Published var launchAtLogin: Bool {
        didSet { changed() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        shouldRegisterLaunchAtLoginByDefault =
            defaults.object(forKey: Key.launchAtLogin) == nil

        defaults.register(defaults: [
            Key.enabled: true,
            Key.focusTransferEnabled: true,
            Key.highlightStyle: HighlightStyle.fullBorder.rawValue,
            Key.highlightColorHex: "#797979",
            Key.edgeGap: 0.0,
            Key.cornerLength: 72.0,
            Key.cornerThickness: 5.0,
            Key.overlayOpacity: 1.0,
            Key.launchAtLogin: true
        ])

        enabled = defaults.bool(forKey: Key.enabled)
        focusTransferEnabled = defaults.bool(forKey: Key.focusTransferEnabled)
        highlightStyle = HighlightStyle(
            rawValue: defaults.string(forKey: Key.highlightStyle) ?? ""
        ) ?? .fullBorder
        highlightColorHex = defaults.string(forKey: Key.highlightColorHex) ?? "#797979"
        edgeGap = defaults.double(forKey: Key.edgeGap)
        cornerLength = defaults.double(forKey: Key.cornerLength)
        cornerThickness = defaults.double(forKey: Key.cornerThickness)
        overlayOpacity = defaults.double(forKey: Key.overlayOpacity)
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        defaults.removeObject(forKey: "glowRadius")
        isLoading = false
    }

    var highlightColor: NSColor {
        NSColor(screenFocusHex: highlightColorHex)
            ?? NSColor(screenFocusHex: "#797979")
            ?? .systemGray
    }

    private func changed() {
        guard !isLoading, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        edgeGap = edgeGap.clamped(to: 0...40)
        cornerLength = cornerLength.clamped(to: 12...72)
        cornerThickness = cornerThickness.clamped(to: 2...14)
        overlayOpacity = overlayOpacity.clamped(to: 0.25...1)

        defaults.set(enabled, forKey: Key.enabled)
        defaults.set(focusTransferEnabled, forKey: Key.focusTransferEnabled)
        defaults.set(highlightStyle.rawValue, forKey: Key.highlightStyle)
        defaults.set(highlightColorHex, forKey: Key.highlightColorHex)
        defaults.set(edgeGap, forKey: Key.edgeGap)
        defaults.set(cornerLength, forKey: Key.cornerLength)
        defaults.set(cornerThickness, forKey: Key.cornerThickness)
        defaults.set(overlayOpacity, forKey: Key.overlayOpacity)
        defaults.set(launchAtLogin, forKey: Key.launchAtLogin)
        onChange?()
    }

    func resetRecommendedAppearance() {
        highlightStyle = .fullBorder
        highlightColorHex = "#797979"
        edgeGap = 0
        cornerLength = 72
        cornerThickness = 5
        overlayOpacity = 1
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension NSColor {
    convenience init?(screenFocusHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            return nil
        }

        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
    }

    var screenFocusHex: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#2F80ED" }
        return String(
            format: "#%02X%02X%02X",
            Int(round(rgb.redComponent * 255)),
            Int(round(rgb.greenComponent * 255)),
            Int(round(rgb.blueComponent * 255))
        )
    }
}
