#!/bin/bash
# Build a disk image that opens with URE.app beside an Applications folder.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
app="${1:?usage: make_dmg.sh URE.app output.dmg}"
dmg="${2:?usage: make_dmg.sh URE.app output.dmg}"
mounted_volume=""
scratch=""

cleanup() {
  if [[ -n "$mounted_volume" && -d "$mounted_volume" ]]; then
    hdiutil detach "$mounted_volume" >/dev/null 2>&1 || hdiutil detach -force "$mounted_volume" >/dev/null 2>&1 || true
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT

background="$ROOT/Config/dmg-background.png"
if [[ ! -f "$background" ]]; then
  swift "$ROOT/Scripts/make_dmg_background.swift" "$background"
fi

kb="$(du -sk "$app" | awk '{print $1}')"
size_mb="$(( kb / 1024 + 32 ))"
scratch="$(mktemp -d)"
rw="$scratch/URE-rw.dmg"

hdiutil create -size "${size_mb}m" -fs APFS -volname "URE" -ov "$rw" >/dev/null
attach="$(hdiutil attach -readwrite -noverify -noautoopen "$rw")"
mounted_volume="$(printf '%s\n' "$attach" | sed -n 's/.*\(\/Volumes\/.*\)$/\1/p' | tail -1)"
if [[ -z "$mounted_volume" || ! -d "$mounted_volume" ]]; then
  echo "Could not mount the disk image." >&2
  printf '%s\n' "$attach" >&2
  exit 1
fi
disk_name="$(basename "$mounted_volume")"

ditto "$app" "$mounted_volume/URE.app"
ln -s /Applications "$mounted_volume/Applications"
mkdir -p "$mounted_volume/.background"
cp "$background" "$mounted_volume/.background/background.png"
if [[ -f "$mounted_volume/URE.app/Contents/Resources/URE_icon.icns" ]]; then
  cp "$mounted_volume/URE.app/Contents/Resources/URE_icon.icns" "$mounted_volume/.VolumeIcon.icns"
  setfile="$(xcrun --find SetFile 2>/dev/null || true)"
  if [[ -n "$setfile" ]]; then
    "$setfile" -a C "$mounted_volume"
  fi
fi

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$disk_name"
    open
    delay 1
    set theWindow to container window
    set current view of theWindow to icon view
    set toolbar visible of theWindow to false
    set statusbar visible of theWindow to false
    set the bounds of theWindow to {240, 120, 880, 528}
    set theOptions to the icon view options of theWindow
    set arrangement of theOptions to not arranged
    set icon size of theOptions to 128
    set text size of theOptions to 13
    set background picture of theOptions to file ".background:background.png"
    delay 1
    set position of item "URE.app" of theWindow to {132, 86}
    set position of item "Applications" of theWindow to {380, 86}
    set extension hidden of item "URE.app" of theWindow to true
    update without registering applications
    delay 2
    close theWindow
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$mounted_volume" >/dev/null
mounted_volume=""
rm -f "$dmg"
hdiutil convert "$rw" -format UDZO -imagekey zlib-level=9 -o "$dmg" >/dev/null
hdiutil verify "$dmg" >/dev/null
