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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: state.status.symbolName)
                    .font(.title2)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ScreenFocus")
                        .font(.headline)
                    Text(state.status.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { settings.enabled },
                    set: { _ in state.toggleEnabled() }
                ))
                .labelsHidden()
            }

            Divider()

            LabeledContent("Pointer display", value: state.pointerDisplayName)

            if !state.accessibilityGranted {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Accessibility permission is needed for focus protection.", systemImage: "lock.open")
                        .font(.callout)
                    Button("Grant Accessibility Access") {
                        state.requestAccessibilityPermission()
                    }
                    Text("ScreenFocus checks this automatically after access is granted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }

            if let lastError = state.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            Button {
                NSRunningApplication.current.activate(options: [])
                openSettings()
            } label: {
                Label("Settings…", systemImage: "gear")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit ScreenFocus", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            state.refreshPermissionStatus()
        }
    }

    private var statusColor: Color {
        switch state.status {
        case .failed:
            .red
        case .guarded, .transitioning:
            .orange
        case .paused:
            .secondary
        default:
            .accentColor
        }
    }
}
