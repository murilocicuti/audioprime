#!/bin/bash
# Installs or updates AudioPrime from the latest GitHub release.
#   curl -fsSL https://raw.githubusercontent.com/murilocicuti/audioprime/main/install.sh | bash
# To uninstall:
#   curl -fsSL https://raw.githubusercontent.com/murilocicuti/audioprime/main/install.sh | bash -s -- --uninstall
set -euo pipefail

REPO="murilocicuti/audioprime"
APP_NAME="AudioPrime.app"
ZIP_URL="${AUDIOPRIME_ZIP_URL:-https://github.com/$REPO/releases/latest/download/AudioPrime.zip}"

say() { printf '\033[1m==>\033[0m %s\n' "$1"; }
fail() { printf '\033[31mError:\033[0m %s\n' "$1" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "AudioPrime only runs on macOS."
# Per-app audio capture (process taps) with a reliable permission prompt: macOS 14.4+.
OS_VERSION="$(sw_vers -productVersion)"
IFS=. read -r MAJOR MINOR _ <<< "$OS_VERSION"
if (( MAJOR < 14 || (MAJOR == 14 && ${MINOR:-0} < 4) )); then
    fail "AudioPrime needs macOS 14.4 (Sonoma) or later. This Mac is on $OS_VERSION.
       Update in System Settings › General › Software Update, then try again."
fi

# /Applications when the user can write there (administrators); otherwise ~/Applications.
if [[ -w /Applications ]]; then DEST_DIR="/Applications"; else DEST_DIR="$HOME/Applications"; fi
DEST="$DEST_DIR/$APP_NAME"

quit_running() {
    if pgrep -x AudioPrime >/dev/null; then
        say "Quitting the running AudioPrime..."
        osascript -e 'tell application id "com.murilo.audioprime" to quit' >/dev/null 2>&1 || pkill -x AudioPrime || true
        sleep 1
    fi
}

if [[ "${1:-}" == "--uninstall" ]]; then
    quit_running
    rm -rf "/Applications/$APP_NAME" "$HOME/Applications/$APP_NAME"
    defaults delete com.murilo.audioprime >/dev/null 2>&1 || true
    say "AudioPrime removed."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "Downloading AudioPrime..."
curl -fL --progress-bar "$ZIP_URL" -o "$TMP/AudioPrime.zip" || fail "couldn't download $ZIP_URL"
ditto -x -k "$TMP/AudioPrime.zip" "$TMP" || fail "the downloaded file is damaged."
[[ -d "$TMP/$APP_NAME" ]] || fail "the download doesn't contain $APP_NAME."

quit_running
say "Installing to $DEST_DIR..."
mkdir -p "$DEST_DIR"
# Remove old copies elsewhere so the Mac never ends up with two AudioPrimes.
for OLD in "/Applications/$APP_NAME" "$HOME/Applications/$APP_NAME" "$HOME/Downloads/$APP_NAME"; do
    if [[ "$OLD" != "$DEST" && -d "$OLD" && -w "$(dirname "$OLD")" ]]; then rm -rf "$OLD"; fi
done
rm -rf "$DEST"
ditto "$TMP/$APP_NAME" "$DEST"
# The app isn't signed by Apple; without the quarantine flag macOS opens it without blocking.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/Contents/Info.plist" 2>/dev/null || echo '?')"
say "AudioPrime $VERSION installed. Opening..."
open "$DEST"
echo
echo "Look for the wave icon in the menu bar. When you adjust your first app,"
echo "macOS will ask for permission to access system audio: click Allow."
