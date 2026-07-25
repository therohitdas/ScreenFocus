import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Enable ScreenFocus", isOn: $settings.enabled)
                Toggle("Transfer focus when the pointer crosses displays", isOn: $settings.focusTransferEnabled)

                Text("When no window is under the pointer, ScreenFocus safely receives ordinary app-level keys. Global shortcuts from macOS, Raycast, Karabiner, and Logitech remain available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Display highlight") {
                Picker("Style", selection: $settings.highlightStyle) {
                    ForEach(HighlightStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                if settings.highlightStyle != .none {
                    ColorPicker(
                        "Color",
                        selection: Binding(
                            get: { Color(nsColor: settings.highlightColor) },
                            set: { settings.highlightColorHex = NSColor($0).screenFocusHex }
                        ),
                        supportsOpacity: false
                    )

                    sliderRow(
                        title: "Edge gap",
                        value: $settings.edgeGap,
                        range: 0...40,
                        suffix: "pt"
                    )

                    if settings.highlightStyle == .cornerMarkers {
                        sliderRow(
                            title: "Corner length",
                            value: $settings.cornerLength,
                            range: 12...72,
                            suffix: "pt"
                        )
                    }

                    sliderRow(
                        title: "Thickness",
                        value: $settings.cornerThickness,
                        range: 2...14,
                        suffix: "pt"
                    )

                    sliderRow(
                        title: "Opacity",
                        value: $settings.overlayOpacity,
                        range: 0.25...1,
                        suffix: "%"
                    )

                }

                HStack {
                    Spacer()
                    Button("Reset to Recommended") {
                        settings.resetRecommendedAppearance()
                    }
                }
            }

            Section("Startup") {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                                settings.launchAtLogin = newValue
                                launchAtLoginError = nil
                            } catch {
                                launchAtLoginError = error.localizedDescription
                            }
                        }
                    )
                )

                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .background(SettingsWindowConfigurator())
    }

    @ViewBuilder
    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        suffix: String
    ) -> some View {
        HStack {
            Text(title)
                .frame(width: 105, alignment: .leading)
            Slider(value: value, in: range)
            Text(formatted(value.wrappedValue, suffix: suffix))
                .monospacedDigit()
                .frame(width: 54, alignment: .trailing)
        }
    }

    private func formatted(_ value: Double, suffix: String) -> String {
        if suffix == "%" {
            return "\(Int((value * 100).rounded()))%"
        }
        return "\(Int(value.rounded())) \(suffix)"
    }
}

private struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        PinnedSettingsProbe()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

@MainActor
private final class PinnedSettingsProbe: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }

        NSRunningApplication.current.activate(options: [])
        SettingsWindowPolicy.apply(to: window)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

@MainActor
enum SettingsWindowPolicy {
    static func apply(to window: NSWindow) {
        window.level = .floating
        window.hidesOnDeactivate = false
        window.collectionBehavior.insert(.moveToActiveSpace)
    }
}
