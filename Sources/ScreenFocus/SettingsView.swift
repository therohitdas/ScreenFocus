// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject var settings: AppSettings

    init(state: AppState) {
        self.state = state
        settings = state.settings
    }

    var body: some View {
        TabView {
            GeneralSettingsView(state: state, settings: settings)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 460, height: 470)
        .background(SettingsWindowConfigurator())
        .onAppear {
            state.refreshLaunchAtLoginStatus()
        }
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Enable ScreenFocus", isOn: $settings.enabled)
                Toggle(
                    "Transfer focus when the pointer crosses displays",
                    isOn: $settings.focusTransferEnabled
                )
                Toggle(
                    "Pause when only one display is connected",
                    isOn: $settings.pauseOnSingleDisplay
                )

                Text(
                    "Empty desktop space is protected without blocking global "
                    + "shortcuts from macOS, Raycast, Karabiner, or Logitech."
                )
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
                            set: {
                                settings.highlightColorHex = NSColor($0).screenFocusHex
                            }
                        ),
                        supportsOpacity: false
                    )

                    sliderRow(
                        title: "Edge gap",
                        value: $settings.edgeGap,
                        range: 0...40,
                        step: 1,
                        suffix: "pt"
                    )

                    if settings.highlightStyle == .cornerMarkers {
                        sliderRow(
                            title: "Corner length",
                            value: $settings.cornerLength,
                            range: 12...72,
                            step: 1,
                            suffix: "pt"
                        )
                    }

                    sliderRow(
                        title: "Thickness",
                        value: $settings.cornerThickness,
                        range: 2...14,
                        step: 1,
                        suffix: "pt"
                    )

                    sliderRow(
                        title: "Opacity",
                        value: $settings.overlayOpacity,
                        range: 0.25...1,
                        step: 0.05,
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
                        set: { enabled in
                            state.setLaunchAtLogin(enabled)
                        }
                    )
                )

                if let launchAtLoginError = state.launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        suffix: String
    ) -> some View {
        HStack {
            Text(title)
                .frame(width: 92, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(formatted(value.wrappedValue, suffix: suffix))
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
        }
    }

    private func formatted(_ value: Double, suffix: String) -> String {
        if suffix == "%" {
            return "\(Int((value * 100).rounded()))%"
        }
        return "\(Int(value.rounded())) \(suffix)"
    }

}

private struct AboutSettingsView: View {
    private var version: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "Development"
    }

    private var build: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)

            VStack(spacing: 4) {
                Text("ScreenFocus")
                    .font(.title2.weight(.semibold))
                Text("Focus that follows your pointer.")
                    .foregroundStyle(.secondary)
                Text("Version \(version) (\(build))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Link(destination: AppLinks.website) {
                HStack(spacing: 5) {
                    Text("Designed & built by Rohit Das")
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)

            VStack(spacing: 0) {
                aboutLink(
                    "Source Code",
                    detail: "View the project on GitHub",
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    destination: AppLinks.sourceCode
                )
                Divider()
                aboutLink(
                    "Report an Issue",
                    detail: "Feedback and bug reports",
                    systemImage: "exclamationmark.bubble",
                    destination: AppLinks.issues
                )
                Divider()
                aboutLink(
                    "End User License Agreement",
                    detail: "Terms for official builds",
                    systemImage: "doc.text",
                    destination: AppLinks.eula
                )
                Divider()
                aboutLink(
                    "Open Source License",
                    detail: "Mozilla Public License 2.0",
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    destination: AppLinks.openSourceLicense
                )
                Divider()
                aboutLink(
                    "Privacy",
                    detail: "What ScreenFocus accesses",
                    systemImage: "hand.raised",
                    destination: AppLinks.privacy
                )
            }
            .background(
                .quaternary.opacity(0.45),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    private func aboutLink(
        _ title: String,
        detail: String,
        systemImage: String,
        destination: URL
    ) -> some View {
        Link(destination: destination) {
            HStack(spacing: 11) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
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
