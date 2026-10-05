#!/bin/bash
# Build a Release URE.app, then write URE-<tag>.zip, URE-<tag>.dmg, and appcast.xml.
# The version comes from the git tag. Do not pass Sparkle's private key on the command line.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPARKLE_VERSION="2.10.0"

raw="${1:?usage: package_release.sh v1.2.3}"
tag="$raw"
if [[ "$tag" != v* ]]; then
  tag="v$tag"
fi
version="${tag#v}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
  echo "Tag must look like v1.2.3, v1.2.3-alpha.1, v1.2.3-beta.1, or v1.2.3-rc.1" >&2
  exit 1
fi

if [[ -z "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  echo "SPARKLE_PRIVATE_KEY is not set. Refusing to publish an unsigned update." >&2
  exit 1
fi

if [[ -z "${URE_APPCAST_URL:-}" || -z "${URE_DOWNLOAD_URL_PREFIX:-}" ]]; then
  origin="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
  repo=""
  if [[ "$origin" =~ github.com[:/]([^/]+/[^/.]+)(\.git)?$ ]]; then
    repo="${BASH_REMATCH[1]}"
  fi
  if [[ -n "$repo" ]]; then
    : "${URE_APPCAST_URL:=https://github.com/${repo}/releases/latest/download/appcast.xml}"
    : "${URE_DOWNLOAD_URL_PREFIX:=https://github.com/${repo}/releases/download/${tag}/}"
  fi
fi

if [[ -z "${URE_APPCAST_URL:-}" || -z "${URE_DOWNLOAD_URL_PREFIX:-}" ]]; then
  echo "Set URE_APPCAST_URL and URE_DOWNLOAD_URL_PREFIX, or add a GitHub origin remote." >&2
  exit 1
fi
if [[ "$URE_APPCAST_URL" != https://* || "$URE_DOWNLOAD_URL_PREFIX" != https://* ]]; then
  echo "Update URLs must use https." >&2
  exit 1
fi
case "$URE_DOWNLOAD_URL_PREFIX" in
  */) ;;
  *) URE_DOWNLOAD_URL_PREFIX="${URE_DOWNLOAD_URL_PREFIX}/" ;;
esac

release_base="${URE_DOWNLOAD_URL_PREFIX%/download/${tag}/}"
release_link="${release_base}/tag/${tag}"

DIST="$ROOT/dist"
DERIVED="${TMPDIR:-/tmp}/URE-release-derived"
APP="$DERIVED/Build/Products/Release/URE.app"
ZIP="$DIST/URE-${tag}.zip"
DMG="$DIST/URE-${tag}.dmg"
APPCAST="$DIST/appcast.xml"
TOOLS="$ROOT/.build/sparkle-${SPARKLE_VERSION}"

rm -rf "$DIST"
mkdir -p "$DIST"

echo "Building URE ${version}"
xcodebuild \
  -project "$ROOT/URE.xcodeproj" \
  -scheme URE \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "$DERIVED" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO \
  MARKETING_VERSION="$version" \
  CURRENT_PROJECT_VERSION="$version" \
  URE_APPCAST_URL="$URE_APPCAST_URL" \
  build

if [[ ! -d "$APP" ]]; then
  echo "URE.app was not produced at $APP" >&2
  exit 1
fi

sign_adhoc() {
  local bundle="$1"
  local item
  while IFS= read -r -d '' item; do
    codesign --force --sign - --timestamp=none "$item" || exit 1
  done < <(find "$bundle" -depth \( -name "*.framework" -o -name "*.xpc" -o -name "*.app" -o -name "*.dylib" \) -print0)
  codesign --verify --deep --strict "$bundle"
}

echo "Ad-hoc signing URE.app"
sign_adhoc "$APP"

short="$(plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist")"
build="$(plutil -extract CFBundleVersion raw -o - "$APP/Contents/Info.plist")"
feed="$(plutil -extract SUFeedURL raw -o - "$APP/Contents/Info.plist")"
public_key="$(plutil -extract SUPublicEDKey raw -o - "$APP/Contents/Info.plist")"
if [[ "$short" != "$version" || "$build" != "$version" ]]; then
  echo "Built version is ${short} (${build}), expected ${version}" >&2
  exit 1
fi
if [[ "$feed" != "$URE_APPCAST_URL" || -z "$public_key" ]]; then
  echo "Sparkle Info.plist keys were not written into the app." >&2
  exit 1
fi
if [[ ! -d "$APP/Contents/Frameworks/Sparkle.framework" ]]; then
  echo "Sparkle.framework is missing from the app." >&2
  exit 1
fi

echo "Creating zip and disk image"
ditto -c -k --keepParent "$APP" "$ZIP"
cleanup() {
  rm -rf "${key_file:-}" "${archives:-}"
}
trap cleanup EXIT
"$ROOT/Scripts/make_dmg.sh" "$APP" "$DMG"

if [[ ! -x "$TOOLS/bin/generate_appcast" ]]; then
  echo "Downloading Sparkle ${SPARKLE_VERSION} tools"
  mkdir -p "$TOOLS"
  archive="$(mktemp)"
  curl -fsSL -o "$archive" "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
  tar -xf "$archive" -C "$TOOLS"
  rm -f "$archive"
fi

key_file="$(mktemp)"
chmod 600 "$key_file"
printf '%s' "$SPARKLE_PRIVATE_KEY" | tr -d '[:space:]' > "$key_file"
archives="$(mktemp -d)"
cp "$ZIP" "$archives/"

echo "Writing appcast"
"$TOOLS/bin/generate_appcast" \
  --ed-key-file "$key_file" \
  --download-url-prefix "$URE_DOWNLOAD_URL_PREFIX" \
  --link "$release_link" \
  -o "$APPCAST" \
  "$archives"

python3 - "$APPCAST" "$version" "$ZIP" "$URE_DOWNLOAD_URL_PREFIX" << 'PY'
import sys
import xml.etree.ElementTree as ET

path, version, zip_path, prefix = sys.argv[1:]
sparkle = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ns = {"sparkle": sparkle}
item = ET.parse(path).getroot().find("./channel/item")
if item is None:
    raise SystemExit("appcast has no item")
got = item.findtext("sparkle:version", namespaces=ns)
if got != version:
    raise SystemExit(f"sparkle:version is {got!r}, expected {version!r}")
enclosure = item.find("enclosure")
if enclosure is None:
    raise SystemExit("appcast enclosure is missing")
signature = enclosure.attrib.get(f"{{{sparkle}}}edSignature", "")
length = enclosure.attrib.get("length", "")
url = enclosure.attrib.get("url", "")
if not signature:
    raise SystemExit("appcast enclosure has no EdDSA signature")
if not length.isdigit() or int(length) != __import__("os").path.getsize(zip_path):
    raise SystemExit(f"appcast length {length!r} does not match the zip")
if not url.startswith(prefix) or not url.endswith(".zip"):
    raise SystemExit(f"unexpected enclosure url {url!r}")
print(f"appcast ok {got} {url}")
PY

echo "Release files:"
ls -lh "$ZIP" "$DMG" "$APPCAST"
