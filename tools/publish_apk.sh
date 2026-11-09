#!/usr/bin/env bash
# Builds the Android APK on this machine and uploads it to Dropbox.
#
#   tools/publish_apk.sh            test-signed APK -> Dropbox /initialsj/initialsj-test.apk
#   tools/publish_apk.sh release    release APK     -> Dropbox /initialsj/initialsj-release.apk
#   tools/publish_apk.sh --no-upload   (or INITIALSJ_NO_UPLOAD=1) build only
#
# It installs the pinned Godot engine when missing (checksum-verified), imports the project,
# runs tools/build_android.sh (export templates, Android SDK and signing are described there and in
# docs/ANDROID.md) and then tools/upload_dropbox.py, which reads DROPBOX_APP_KEY, DROPBOX_APP_SECRET
# and DROPBOX_REFRESH_TOKEN from the environment. The first run downloads about 1.5 GB (templates and
# SDK); ANDROID_ACCEPT_LICENSES=1 accepts Google's Android SDK licence for that install.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
kind="debug"
upload=1
[[ "${INITIALSJ_NO_UPLOAD:-}" == "1" ]] && upload=0
for arg in "$@"; do
  case "$arg" in
    debug) kind="debug" ;;
    release) kind="release" ;;
    --no-upload) upload=0 ;;
    *) echo "Usage: tools/publish_apk.sh [debug|release] [--no-upload]" >&2; exit 2 ;;
  esac
done
version="$(tr -d '[:space:]' < .godot-version)"

if ! ./tools/godot --version > /dev/null 2>&1; then
  echo "Installing Godot $version ..."
  base="https://github.com/godotengine/godot/releases/download/$version-stable"
  archive="Godot_v$version-stable_linux.x86_64.zip"
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  curl -fL -o "$work/$archive" "$base/$archive"
  curl -fL -o "$work/SHA512-SUMS.txt" "$base/SHA512-SUMS.txt"
  (cd "$work" && grep " $archive\$" SHA512-SUMS.txt | sha512sum -c -)
  engines="$HOME/.local/share/godot/engines/$version"
  mkdir -p "$engines"
  unzip -q -o "$work/$archive" -d "$engines"
  chmod +x "$engines/Godot_v$version-stable_linux.x86_64"
fi

if [[ "$upload" == "1" && -z "${DROPBOX_ACCESS_TOKEN:-}" ]]; then
  : "${DROPBOX_APP_KEY:?Set DROPBOX_APP_KEY, DROPBOX_APP_SECRET and DROPBOX_REFRESH_TOKEN (or pass --no-upload)}"
  : "${DROPBOX_APP_SECRET:?Set DROPBOX_APP_SECRET}"
  : "${DROPBOX_REFRESH_TOKEN:?Set DROPBOX_REFRESH_TOKEN}"
fi

./tools/godot --headless --path . --editor --import --quit
tools/build_android.sh "$kind"

apk="build/android/initialsj-$kind.apk"
if [[ "$upload" == "1" ]]; then
  # The test build keeps its historic public name; the key it is signed with decides which phones it can update.
  name="initialsj-$([[ "$kind" == "debug" ]] && echo test || echo release).apk"
  python3 tools/upload_dropbox.py "$apk" --name "$name"
else
  echo "Skipped the Dropbox upload. APK: $apk"
fi
