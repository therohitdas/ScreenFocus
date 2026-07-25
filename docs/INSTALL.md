# Install ScreenFocus

## Requirements

- macOS 14 or later.
- Apple Silicon or Intel Mac.
- Accessibility permission for focus transfer.

## Install a release

1. Download `ScreenFocus-x.y.z.zip` from the repository's Releases page.
2. Verify the checksum if one is provided:

   ```sh
   shasum -a 256 ScreenFocus-x.y.z.zip
   ```

3. Double-click the ZIP file.
4. Drag `ScreenFocus.app` into `/Applications`.
5. Open ScreenFocus from Applications.

Keep the app in `/Applications`. Moving it after granting Accessibility access
can make macOS treat it as a different copy.

## If macOS blocks the app

ScreenFocus is locally signed but is not notarized by Apple.

Use Apple's normal override first:

1. Try to open ScreenFocus once.
2. Open **System Settings → Privacy & Security**.
3. Scroll to **Security**.
4. Select **Open Anyway**, then confirm.

The button is normally available for about an hour after the blocked launch.
See Apple's
[official instructions](https://support.apple.com/guide/mac-help/mh40616/mac).

### Trusted-download Terminal fallback

Only if you downloaded ScreenFocus from this repository and trust the archive:

```sh
xattr -dr com.apple.quarantine /Applications/ScreenFocus.app
open /Applications/ScreenFocus.app
```

`xattr -d` deletes one extended attribute and `-r` applies that operation
recursively through the app bundle. This bypasses the downloaded-file warning;
it does not grant Accessibility permission.

## Enable focus transfer

1. Open the ScreenFocus menu-bar item.
2. Select **Grant Accessibility Access**.
3. Enable ScreenFocus under
   **System Settings → Privacy & Security → Accessibility**.
4. Wait a moment for the menu to show **Aligned**.

If the permission notice remains:

1. Confirm you enabled `/Applications/ScreenFocus.app`, not a copy in Downloads.
2. Quit ScreenFocus.
3. Turn its Accessibility switch off and back on.
4. Open ScreenFocus again.

You do not need Screen Recording, Input Monitoring, microphone, or system-audio
access.

## Update

1. Quit ScreenFocus.
2. Replace `/Applications/ScreenFocus.app` with the newer release.
3. Open it again.

Releases from this repository use the same code-signing identity, so
Accessibility approval should normally remain intact.

## Uninstall

1. Quit ScreenFocus from its menu-bar item.
2. Delete `/Applications/ScreenFocus.app`.
3. Remove ScreenFocus from
   **System Settings → Privacy & Security → Accessibility**.

Optional: remove saved preferences:

```sh
defaults delete com.rohitdas.ScreenFocus
```
