# Privacy

ScreenFocus is local-only.

## What it accesses

ScreenFocus uses the macOS Accessibility API to:

- Identify the interface element and window beneath the pointer.
- Activate the owning application.
- Raise and focus that window.
- Verify which application and window received focus.

## What it does not do

- No Screen Recording.
- No screenshots or OCR.
- No global keyboard logging.
- No microphone or system-audio capture.
- No analytics or telemetry.
- No network requests.
- No account or cloud service.

## Local data

The app stores only its preferences in macOS `UserDefaults`, including:

- Enabled state.
- Focus-transfer setting.
- Overlay style, color, dimensions, and opacity.
- Launch-at-login preference.

The preferences domain is:

```text
com.rohitdas.ScreenFocus
```

Remove saved preferences with:

```sh
defaults delete com.rohitdas.ScreenFocus
```
