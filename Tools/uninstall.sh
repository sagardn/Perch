#!/bin/sh
#
# Removes Perch and everything it leaves on a Mac.
#
#   sh /Applications/Perch.app/Contents/Resources/Scripts/uninstall.sh
#   sh Tools/uninstall.sh            # if the app is already in the Trash
#
# The list is what Perch itself writes, and nothing else: the app, its
# preferences domain, its Application Support folder, the caches and saved
# state macOS keeps for it, and the Accessibility and notification grants.
# Perch installs no helper, no launch daemon and no kernel extension, so
# nothing here needs administrator rights unless the app was copied into
# /Applications by another user.
#
# Run it as yourself, not with sudo: every path but the app is in your home
# folder, and the permission resets are per user.

set -u

ID="com.sagar.perch"

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this without sudo -- Perch's data is in your home folder." >&2
    exit 1
fi

echo "Quitting Perch..."
osascript -e "quit app id \"$ID\"" >/dev/null 2>&1 || true
pkill -x Perch >/dev/null 2>&1 || true

echo "Removing the app..."
for app in "/Applications/Perch.app" "$HOME/Applications/Perch.app"; do
    [ -d "$app" ] || continue
    rm -rf "$app" 2>/dev/null || {
        echo "  $app needs an administrator to remove:"
        sudo rm -rf "$app"
    }
done

echo "Removing preferences and data..."
defaults delete "$ID" >/dev/null 2>&1 || true
defaults delete "$ID.LaunchAtLogin" >/dev/null 2>&1 || true
rm -rf \
    "$HOME/Library/Application Support/Perch" \
    "$HOME/Library/Caches/$ID" \
    "$HOME/Library/HTTPStorages/$ID" \
    "$HOME/Library/Saved Application State/$ID.savedState" \
    "$HOME/Library/Preferences/$ID.plist" \
    "$HOME/Library/Preferences/$ID.LaunchAtLogin.plist"

# The login item is registered through SMAppService against the app's own
# bundle, so it goes when the bundle does; System Settings drops the entry
# on its next refresh. The two grants below do not -- macOS keeps them by
# bundle identifier -- so a reinstall would otherwise inherit stale ones.
echo "Resetting Accessibility and notification permissions..."
tccutil reset Accessibility "$ID" >/dev/null 2>&1 || true
tccutil reset All "$ID" >/dev/null 2>&1 || true

echo "Perch has been uninstalled."
