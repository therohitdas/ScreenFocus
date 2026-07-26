import AppKit
import SwiftUI

struct MenuPanelView: View {
    @Environment(\.openSettings) private var openSettings
    @ObservedObject private var state: AppState
    @ObservedObject private var settings: AppSettings

    init(state: AppState) {
        self.state = state
        settings = state.settings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: state.status.symbolName)
                    .font(.title2)
                    .foregroundStyle(.tint)

                Text("ScreenFocus")
                    .font(.headline)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(statusIndicatorColor)
                        .frame(width: 7, height: 7)

                    Text(state.trayStatusTitle)
                        .font(.callout.weight(.medium))

                    Spacer()

                    Button {
                        state.toggleEnabled()
                    } label: {
                        Label(
                            settings.enabled ? "Pause" : "Resume",
                            systemImage: settings.enabled ? "pause.fill" : "play.fill"
                        )
                    }
                    .buttonStyle(TrayControlButtonStyle())
                    .focusable(false)
                    .focusEffectDisabled()
                    .help(settings.enabled ? "Pause ScreenFocus" : "Resume ScreenFocus")
                }

                LabeledContent("Pointer display", value: state.pointerDisplayName)

                if state.availability.isActive,
                   settings.focusTransferEnabled,
                   !state.accessibilityGranted {
                    VStack(alignment: .leading, spacing: 7) {
                        Label(
                            "Accessibility access is needed for focus protection.",
                            systemImage: "lock.open"
                        )
                        .font(.callout)

                        Button("Grant Accessibility Access") {
                            state.requestAccessibilityPermission()
                        }
                        .focusEffectDisabled()

                        Text("ScreenFocus refreshes automatically after access is granted.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(9)
                    .background(
                        .orange.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                }

                if let lastError = state.lastError {
                    Text(lastError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                Button {
                    NSRunningApplication.current.activate(options: [])
                    openSettings()
                } label: {
                    actionRow("Settings…", systemImage: "gear")
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    actionRow("Quit ScreenFocus", systemImage: "power")
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
            }
            .padding(.vertical, 4)

            Divider()

            Link(destination: AppLinks.website) {
                HStack(spacing: 5) {
                    Text("Independent software by Rohit Das")
                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 292)
        .onAppear {
            state.refreshPermissionStatus()
        }
    }

    private func actionRow(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
    }

    private var statusIndicatorColor: Color {
        guard state.availability.isActive else {
            return .secondary
        }

        return switch state.status {
        case .failed:
            .red
        case .highlightOnly:
            .orange
        default:
            .green
        }
    }
}

private struct TrayControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Color.secondary.opacity(configuration.isPressed ? 0.24 : 0.14),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Rectangle())
    }
}
