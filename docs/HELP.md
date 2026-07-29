# ScreenFocus Help

## What happens when the pointer crosses displays?

ScreenFocus immediately shows the configured highlight on the destination
display. It then asks macOS Accessibility for the interface element under the
pointer, finds its containing window, activates the owning application, raises
the window, and verifies that the window received focus.

This happens only when the pointer crosses between displays. Moving within one
display does not repeatedly change focus.

When the window under the crossing point is overlapped by a higher window,
ScreenFocus focuses that topmost overlapping window instead. Separate
side-by-side windows still follow the pointer normally.

## What happens over empty space?

When no suitable window exists under the pointer, ScreenFocus activates a tiny
transparent focus-guard window on that display. This prevents ordinary typing
from continuing into a text field on the previous display.

ScreenFocus does not intercept or discard global keyboard events. System-wide
shortcuts from macOS and tools such as Raycast, Karabiner-Elements, and Logitech
software remain available.

## Tray statuses

| Status | Meaning |
|---|---|
| Active | Highlighting and focus protection are ready |
| Active — Highlight only | Focus transfer is turned off |
| Active — Needs accessibility | Highlighting works, but focus protection needs permission |
| Disabled — Paused | ScreenFocus was paused manually |
| Disabled — One display | Automatic single-display pause is active |

The visual highlight always uses your selected color. Red is reserved for a
verified failure.

## Settings

### Enable ScreenFocus

Pauses or resumes both focus behavior and the overlay.

### Transfer focus when the pointer crosses displays

Turn this off to use ScreenFocus only as a display indicator.

### Pause when only one display is connected

Stops focus handling and hides the overlay while macOS reports only one
connected display. ScreenFocus resumes automatically when a second display
reconnects. This setting is enabled by default.

### Style

- **Full border:** Highlights all four display edges.
- **Corner markers:** Shows four L-shaped markers.
- **Off:** Hides the overlay without disabling focus transfer.

### Appearance

- **Color:** Normal highlight color.
- **Edge gap:** Distance from the display edge.
- **Thickness:** Width of the highlight.
- **Opacity:** Visibility of the highlight.
- **Corner length:** Length of L-shaped markers.

On a built-in Mac display, the full border automatically follows the display's
rounded corners and wraps around its camera housing when present. External
displays keep square corners. There is no separate setting or permission.

### Launch at login

Starts ScreenFocus automatically after you sign in. This is enabled by default
on first launch and can be turned off at any time.

## Troubleshooting

### The border works, but focus does not

ScreenFocus is running in highlight-only mode. Open the menu and check whether
it asks for Accessibility permission.

If access appears enabled but the warning remains:

1. Quit ScreenFocus.
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Toggle ScreenFocus off and on.
4. Open `/Applications/ScreenFocus.app` again.

Make sure the allowed copy is the same copy you are running.

### Focus works until I open Settings

Update to version 0.3.1 or later. Older builds incorrectly stopped focus
transfer while ScreenFocus itself was active.

### The wrong window receives focus

- Confirm the pointer is over the intended window, not desktop space.
- Some custom-drawn applications expose incomplete Accessibility information.
- macOS system surfaces such as Dock, Control Center, Notification Center, and
  Window Manager are intentionally excluded as targets.
- Move the pointer fully across the display boundary; ScreenFocus uses a small
  inset to prevent rapid switching at the seam.

### Focus does not change while dragging

This is intentional. ScreenFocus waits until all mouse buttons are released so
it does not interrupt a cross-display drag.

### A shortcut still runs globally

Also intentional. ScreenFocus protects ordinary application-level typing but
does not consume global shortcuts. Raycast, Karabiner-Elements, Logitech, and
macOS shortcuts can continue to run.

### The app disappeared

ScreenFocus has no Dock icon. Look for its focus-frame icon in the menu bar. If
it is not running:

```sh
open /Applications/ScreenFocus.app
```

### Reset appearance

Open **Settings… → Reset to Recommended**. This restores the Steel full border,
0-point gap, 5-point thickness, and 100% opacity.

## Report a problem

When opening an issue, include:

- macOS version.
- Mac model and processor.
- Display arrangement.
- Application that should have received focus.
- Whether the pointer was over a window or empty space.
- ScreenFocus menu status.

Do not include private document text or unrelated screenshots.
