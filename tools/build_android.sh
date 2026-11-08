#!/usr/bin/env bash
# Builds the Android APK (arm64, GL Compatibility) with the pinned Godot version.
#
#   tools/build_android.sh            test-signed APK   -> build/android/initialsj-debug.apk
#   tools/build_android.sh release    release template  -> build/android/initialsj-release.apk
#
# First run installs what is missing: the Android export templates (about 1.3 GB download), the
# Android SDK command-line tools with platform 35 and build-tools 35.0.1, and a debug keystore.
# Installing the SDK means accepting Google's Android SDK licence, so it only happens when you
# set ANDROID_ACCEPT_LICENSES=1.
#
# The debug build is signed with tools/android-test.keystore, a shared TEST key (its password is in
# this script and in the repository, so anyone can sign with it). It keeps the signature stable so
# test builds update over each other. Never publish an app signed with it.
#
# A release APK must be signed with YOUR keystore (never commit it). Provide it with
#   INITIALSJ_KEYSTORE=/path/release.keystore INITIALSJ_KEY_ALIAS=alias INITIALSJ_KEY_PASSWORD=...
# See docs/ANDROID.md.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
version="$(tr -d '[:space:]' < .godot-version)"
kind="${1:-debug}"
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
templates="$HOME/.local/share/godot/export_templates/$version.stable"
keystore_dir="$HOME/.local/share/godot/keystores"
debug_keystore="$keystore_dir/debug.keystore"
settings="$HOME/.config/godot/editor_settings-${version%.*}.tres"

if [[ ! -f "$templates/android_debug.apk" || ! -f "$templates/android_release.apk" ]]; then
  echo "Installing the Android export templates for Godot $version ..."
  work="$(mktemp -d)"
  curl -fL -o "$work/templates.tpz" "https://github.com/godotengine/godot/releases/download/$version-stable/Godot_v$version-stable_export_templates.tpz"
  mkdir -p "$templates"
  unzip -q -o "$work/templates.tpz" 'templates/android*' 'templates/version.txt' -d "$work"
  cp "$work"/templates/android_* "$work/templates/version.txt" "$templates/"
  rm -rf "$work"
fi

if [[ ! -x "$sdk/build-tools/35.0.1/apksigner" || ! -d "$sdk/platforms/android-35" ]]; then
  if [[ "${ANDROID_ACCEPT_LICENSES:-}" != "1" ]]; then
    echo "The Android SDK (platform 35, build-tools 35.0.1) is missing at $sdk." >&2
    echo "Install it yourself, or re-run with ANDROID_ACCEPT_LICENSES=1 to accept Google's SDK licence and install it here." >&2
    exit 2
  fi
  mkdir -p "$sdk/cmdline-tools"
  if [[ ! -x "$sdk/cmdline-tools/latest/bin/sdkmanager" ]]; then
    work="$(mktemp -d)"
    curl -fL -o "$work/tools.zip" "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
    unzip -q "$work/tools.zip" -d "$work"
    rm -rf "$sdk/cmdline-tools/latest"
    mv "$work/cmdline-tools" "$sdk/cmdline-tools/latest"
    rm -rf "$work"
  fi
  yes | "$sdk/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$sdk" --licenses > /dev/null || true
  "$sdk/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$sdk" "platform-tools" "build-tools;35.0.1" "platforms;android-35"
fi

if [[ ! -f "$debug_keystore" ]]; then
  mkdir -p "$keystore_dir"
  keytool -genkeypair -keystore "$debug_keystore" -storepass android -alias androiddebugkey -keypass android \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
fi

# Godot reads the SDK, JDK and debug keystore from its editor settings.
java_home="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")}"
mkdir -p "$(dirname "$settings")"
[[ -f "$settings" ]] || printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$settings"
set_setting() {
  if grep -q "^$1 = " "$settings"; then sed -i "s|^$1 = .*|$1 = \"$2\"|" "$settings"; else printf '%s = "%s"\n' "$1" "$2" >> "$settings"; fi
}
set_setting export/android/android_sdk_path "$sdk"
set_setting export/android/java_sdk_path "$java_home"
set_setting export/android/debug_keystore "$debug_keystore"
set_setting export/android/debug_keystore_user "androiddebugkey"
set_setting export/android/debug_keystore_pass "android"

mkdir -p build/android
if [[ "$kind" == "release" ]]; then
  : "${INITIALSJ_KEYSTORE:?Set INITIALSJ_KEYSTORE to your release keystore (see docs/ANDROID.md)}"
  : "${INITIALSJ_KEY_ALIAS:?Set INITIALSJ_KEY_ALIAS}"
  : "${INITIALSJ_KEY_PASSWORD:?Set INITIALSJ_KEY_PASSWORD}"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$INITIALSJ_KEYSTORE"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$INITIALSJ_KEY_ALIAS"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$INITIALSJ_KEY_PASSWORD"
  out="build/android/initialsj-release.apk"
  ./tools/godot --headless --path . --export-release Android "$out"
else
  out="build/android/initialsj-debug.apk"
  export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$PWD/tools/android-test.keystore"
  export GODOT_ANDROID_KEYSTORE_DEBUG_USER="initialsj-test"
  export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="initialsj-test"
  ./tools/godot --headless --path . --export-debug Android "$out"
fi
"$sdk/build-tools/35.0.1/apksigner" verify "$out" > /dev/null
echo "Built $out ($(du -h "$out" | cut -f1)). Install with: adb install -r $out"
