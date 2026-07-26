# Changelog

## 0.5.1

- Removed the keyboard-focus outline from the tray Pause/Resume button.

## 0.5.0

- Added an option to pause automatically when only one display is connected.
- Added a clear Active or Disabled status with a short reason in the tray.
- Moved Pause/Resume from the header into the status row.
- Automatically resumes when a second display reconnects.

## 0.4.4

- Enabled Launch at Login by default on first launch.
- Synced the Settings toggle with the real macOS Login Items state.
- Preserved a stored preference when Launch at Login was previously disabled.

## 0.4.3

- Redesigned the app icon as a polished macOS squircle.
- Removed the opaque black canvas around the icon.
- Added a repeatable icon builder for every required macOS icon size.

## 0.4.2

- Removed the distracting focus ring from tray controls.
- Fixed Resume immediately restoring the live status and menu-bar icon.

## 0.4.1

- Replaced the tray toggle with a compact Pause/Resume button.
- Removed the status subtitle beneath the ScreenFocus name.
- Added release-time verification that the app icon is present in the bundle.

## 0.4.0

- Fixed double-painted corner pixels at reduced overlay opacity.
- Made full-border and corner-marker geometry seamless.
- Refined tray and Settings spacing for a more native macOS appearance.
- Added a dedicated About tab with author, website, source, issues, EULA, and
  privacy links.
- Added public-facing legal and attribution metadata.

## 0.3.3

- Show the configured highlight instantly when crossing displays.
- Remove the temporary yellow focus-transition treatment.
- Preserve the configured color for guarded empty-space behavior.

## 0.3.2

- Replaced the yellow transition with opacity-based feedback.

## 0.3.1

- Fixed focus transfer being suppressed while the pinned Settings window was
  active.
- Added stable local code signing so Accessibility approval survives rebuilds.
- Improved live Accessibility-permission status.

## 0.3.0

- Added full-border, corner-marker, and hidden overlay styles.
- Added editable color, edge gap, thickness, opacity, and corner length.
- Added pinned Settings behavior.
- Adopted the Steel full-border default.

## 0.2.0

- Added Accessibility-based window focus transfer.
- Added the empty-space focus guard.

## 0.1.0

- Initial menu-bar MVP with multi-display pointer detection and highlighting.
