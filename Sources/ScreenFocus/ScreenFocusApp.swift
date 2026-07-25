import AppKit
import SwiftUI

@main
struct ScreenFocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView(state: appState)
        } label: {
            Label("ScreenFocus", systemImage: appState.status.symbolName)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(state: appState)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
