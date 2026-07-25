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
                    .foregroundStyle(statusColor)

                Text("ScreenFocus")
                    .font(.headline)

                Spacer()

                Button {
                    state.toggleEnabled()
                } label: {
                    Label(
                        settings.enabled ? "Pause" : "Resume",
                        systemImage: settings.enabled ? "pause.fill" : "play.fill"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(settings.enabled ? "Pause ScreenFocus" : "Resume ScreenFocus")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            VStack(alignment: .leading, spacing: 9) {
                LabeledContent("Pointer display", value: state.pointerDisplayName)

                if !state.accessibilityGranted {
                    VStack(alignment: .leading, spacing: 7) {
                        Label(
                            "Accessibility access is needed for focus protection.",
                            systemImage: "lock.open"
                        )
                        .font(.callout)

                        Button("Grant Accessibility Access") {
                            state.requestAccessibilityPermission()
                        }

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

                Button {
                    NSApp.terminate(nil)
                } label: {
                    actionRow("Quit ScreenFocus", systemImage: "power")
                }
                .buttonStyle(.plain)
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

    private var statusColor: Color {
        switch state.status {
        case .failed:
            .red
        case .highlightOnly:
            .orange
        case .paused:
            .secondary
        default:
            .accentColor
        }
    }
}
