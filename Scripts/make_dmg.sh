#!/bin/bash
# Build a drag-to-Applications disk image with create-dmg.
#
# Icon positions and the arrow use one coordinate system: the Finder icon view,
# origin at the top left. The background image is exactly that view, at 72 dpi.
# The title bar is not part of the image. On this macOS it is 32 points tall
# when the toolbar and status bar are hidden.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CREATE_DMG_VERSION="1.3.0"

window_width=560
window_height=300
title_bar=32
icon_size=128
app_x=160
drop_x=400
icon_y=123
view_width="$window_width"
view_height="$((window_height - title_bar))"
arrow_x="$(( (app_x + drop_x) / 2 ))"
arrow_y="$icon_y"

app="${1:?usage: make_dmg.sh URE.app output.dmg}"
dmg="${2:?usage: make_dmg.sh URE.app output.dmg}"
stage=""

cleanup() {
  rm -rf "$stage"
}
trap cleanup EXIT

tool_dir="$ROOT/.build/create-dmg-${CREATE_DMG_VERSION}"
tool="$tool_dir/create-dmg"
template="$tool_dir/support/template.applescript"
if [[ ! -x "$tool" || ! -f "$template" ]]; then
  echo "Downloading create-dmg ${CREATE_DMG_VERSION}"
  mkdir -p "$ROOT/.build"
  archive="$(mktemp)"
  curl -fsSL -o "$archive" "https://github.com/create-dmg/create-dmg/archive/refs/tags/v${CREATE_DMG_VERSION}.tar.gz"
  rm -rf "$tool_dir"
  tar -xzf "$archive" -C "$ROOT/.build"
  rm -f "$archive"
  chmod +x "$tool"
fi

# The last item create-dmg positions stays selected. Clear that before Finder saves .DS_Store.
python3 - "$template" << 'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
needle = "\t\t--give the finder some time to write the .DS_Store file\n"
if "set selection to {}" not in text:
    if needle not in text:
        raise SystemExit("create-dmg template changed; cannot clear the icon selection")
    path.write_text(text.replace(needle, "\t\tset selection to {}\n" + needle, 1))
PY

background="$ROOT/Config/dmg-background.png"
swift "$ROOT/Scripts/make_dmg_background.swift" "$background" "$view_width" "$view_height" "$arrow_x" "$arrow_y"

stage="$(mktemp -d)"
ditto "$app" "$stage/URE.app"
osascript -e "tell application \"Finder\" to make new alias file at (POSIX file \"${stage}\") to (POSIX file \"/Applications\")" >/dev/null
drop_name=""
for entry in "$stage"/*; do
  base="$(basename "$entry")"
  if [[ "$base" != "URE.app" ]]; then
    drop_name="$base"
  fi
done
if [[ -z "$drop_name" ]]; then
  echo "Could not create the Applications alias." >&2
  exit 1
fi

args=(
  --volname "URE"
  --background "$background"
  --window-pos 200 120
  --window-size "$window_width" "$window_height"
  --icon-size "$icon_size"
  --text-size 13
  --icon "URE.app" "$app_x" "$icon_y"
  --hide-extension "URE.app"
  --icon "$drop_name" "$drop_x" "$icon_y"
  --filesystem APFS
  --no-internet-enable
  --overwrite
)

icon="$stage/URE.app/Contents/Resources/URE_icon.icns"
if [[ -f "$icon" ]] && setfile="$(xcrun --find SetFile 2>/dev/null)"; then
  export PATH="$(dirname "$setfile"):${PATH}"
  args+=(--volicon "$icon")
fi

mkdir -p "$(dirname "$dmg")"
"$tool" "${args[@]}" "$dmg" "$stage"
hdiutil verify "$dmg" >/dev/null
