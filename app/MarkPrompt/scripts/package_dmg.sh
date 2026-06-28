#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MarkPrompt"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PACKAGE_DIR/../.." && pwd)"

INFO_PLIST="$PACKAGE_DIR/Sources/MarkPrompt/App/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"

BUILD_ROOT="$REPO_ROOT/build"
APP_BUNDLE="$BUILD_ROOT/$APP_NAME.app"
RW_DMG_PATH="$BUILD_ROOT/$APP_NAME-$VERSION-rw.dmg"
DMG_PATH="$BUILD_ROOT/$APP_NAME-$VERSION.dmg"
ICON_FILE="$PACKAGE_DIR/Sources/MarkPrompt/Resources/AppIcon.icns"

"$SCRIPT_DIR/package_app.sh"

rm -f "$RW_DMG_PATH" "$DMG_PATH"

hdiutil create \
    -size 64m \
    -fs HFS+ \
    -volname "$APP_NAME" \
    -ov \
    "$RW_DMG_PATH" >/dev/null

ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -nobrowse "$RW_DMG_PATH")"
MOUNT_DIR="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"

cleanup() {
    if [[ -n "${MOUNT_DIR:-}" ]] && [[ -d "$MOUNT_DIR" ]]; then
        hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

ditto "$APP_BUNDLE" "$MOUNT_DIR/$APP_NAME.app"
ln -s /Applications "$MOUNT_DIR/Applications"

osascript <<APPLESCRIPT
set mountedVolume to POSIX file "$MOUNT_DIR" as alias

tell application "Finder"
    open mountedVolume
    set dmgWindow to container window of mountedVolume
    set current view of dmgWindow to icon view
    set toolbar visible of dmgWindow to false
    set statusbar visible of dmgWindow to false
    set bounds of dmgWindow to {180, 120, 1080, 640}

    set viewOptions to icon view options of dmgWindow
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 160
    set text size of viewOptions to 16
    set label position of viewOptions to bottom
    set background color of viewOptions to {65535, 65535, 65535}

    set position of item "$APP_NAME.app" of mountedVolume to {240, 300}
    set position of item "Applications" of mountedVolume to {660, 300}
    update mountedVolume without registering applications
    delay 2
    close dmgWindow
    delay 1
end tell
APPLESCRIPT

cp "$ICON_FILE" "$MOUNT_DIR/.VolumeIcon.icns"
SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns"
SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns"
SetFile -a C "$MOUNT_DIR"

sync
hdiutil detach "$MOUNT_DIR" >/dev/null
MOUNT_DIR=""
trap - EXIT

hdiutil convert "$RW_DMG_PATH" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" >/dev/null

rm -f "$RW_DMG_PATH"

hdiutil verify "$DMG_PATH" >/dev/null

printf '%s\n' "$DMG_PATH"
