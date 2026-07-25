# Development

## Stack

- Swift 6.2.
- SwiftUI for the menu and Settings interface.
- AppKit for transparent overlay panels and application lifecycle behavior.
- macOS Accessibility API for hit-testing and focus control.
- ServiceManagement for launch at login.
- Swift Package Manager for builds and tests.

## Project layout

```text
Sources/ScreenFocus/
  AccessibilityClient.swift   AX hit-testing, activation, and verification
  AppSettings.swift           UserDefaults-backed preferences
  AppState.swift              Main application coordinator
  CrossingDetector.swift      Display transition and drag suppression
  DisplayRegistry.swift       NSScreen / display mapping
  FocusGuardController.swift  Empty-space keyboard focus guard
  MenuPanelView.swift         Menu-bar interface
  OverlayController.swift     Full-border and corner overlays
  PointerMonitor.swift        Pointer sampling
  ScreenFocusApp.swift        SwiftUI app entry point
  SettingsView.swift          Preferences window

Packaging/
  Info.plist
  ScreenFocus.icns

scripts/
  setup-local-signing.sh
  build-app.sh
  package-release.sh
```

## Build

Install the stable local signing identity once:

```sh
./scripts/setup-local-signing.sh
```

Then build the Universal app:

```sh
./scripts/build-app.sh
```

Output:

```text
dist/ScreenFocus.app
```

The signing script creates a self-signed ScreenFocus code-signing identity in
the current user's login keychain. A stable identity prevents macOS
Accessibility approval from being invalidated on every rebuild.

To use another identity:

```sh
SCREENFOCUS_SIGNING_IDENTITY="Apple Development: Your Name" \
  ./scripts/build-app.sh
```

## Test

```sh
swift test
```

Before releasing, also test manually with two displays:

1. Focus a text field on Display 1.
2. Move the pointer over a normal window on Display 2 without clicking.
3. Press `Command-M` and confirm the Display 2 window minimizes.
4. Repeat with empty desktop space and confirm ordinary typing does not reach
   the original text field.
5. Confirm a known global shortcut still works.
6. Test Full border, Corner markers, and Off.

## Package

```sh
./scripts/package-release.sh
```

This creates:

```text
dist/ScreenFocus-x.y.z.zip
dist/ScreenFocus-x.y.z.zip.sha256
```

The script verifies the signature and ZIP structure.

## Versioning

Update both values in `Packaging/Info.plist`:

- `CFBundleShortVersionString`: public semantic version.
- `CFBundleVersion`: monotonically increasing build number.

Then update `CHANGELOG.md` and the version shown in `README.md`.

## Architecture notes

The focus pipeline is intentionally event-light:

1. `PointerMonitor` samples pointer location.
2. `CrossingDetector` emits only initial placement or a real display crossing.
3. `AppState` updates the overlay immediately.
4. `AccessibilityClient` resolves and focuses a target window.
5. `FocusGuardController` activates only if no target can be verified.

Overlay panels ignore mouse events and do not become key windows.
