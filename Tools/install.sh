#!/bin/bash
#
# Installs the latest Perch release.
#
# Why this exists: Perch is signed ad hoc rather than with a paid Apple
# Developer ID, so macOS refuses to open it when it arrives through a browser
# -- and since macOS 15 the old right-click-Open escape hatch is gone, leaving
# a dialog whose only buttons are "Move to Trash" and "Done".
#
# Quarantine is attached by the program that downloads a file, not by the file
# itself. curl does not attach it, so fetching the DMG this way skips Gatekeeper
# entirely. Nothing here disables a security feature system-wide: the xattr call
# only clears the flag on this one app, and only if one is present.
#
#   curl -fsSL https://raw.githubusercontent.com/sagardn/Perch/main/Tools/install.sh | bash
#
set -euo pipefail

DMG_URL="https://github.com/sagardn/Perch/releases/latest/download/Perch.dmg"
DMG="$(mktemp -t Perch).dmg"
MOUNT="/Volumes/Perch"

cleanup() {
    [ -d "$MOUNT" ] && hdiutil detach "$MOUNT" -quiet || true
    rm -f "$DMG"
}
trap cleanup EXIT

echo "==> downloading Perch"
curl -fsSL "$DMG_URL" -o "$DMG"

echo "==> verifying the disk image"
# A truncated or half-served download fails here rather than half-installing.
hdiutil verify "$DMG" >/dev/null

echo "==> mounting"
[ -d "$MOUNT" ] && hdiutil detach "$MOUNT" -quiet || true
hdiutil attach "$DMG" -nobrowse -quiet

if pgrep -f "/Applications/Perch.app/Contents/MacOS/Perch" >/dev/null; then
    echo "==> quitting the running copy"
    pkill -f "/Applications/Perch.app/Contents/MacOS/Perch" || true
    sleep 2
fi

echo "==> installing to /Applications"
rm -rf /Applications/Perch.app
cp -R "$MOUNT/Perch.app" /Applications/
xattr -dr com.apple.quarantine /Applications/Perch.app 2>/dev/null || true

echo "==> launching"
open /Applications/Perch.app

cat <<'NOTE'

Perch is running in your menu bar.

It needs Accessibility to move and minimise windows:
  System Settings > Privacy & Security > Accessibility > enable Perch

NOTE
