# Android APK

The Android build uses the same project and the same code as the web build. Only the export preset
differs (`Android` in [export_presets.cfg](../export_presets.cfg)). Nothing in the game scripts
changes between platforms except a few `OS.has_feature("web")` / `("android")` branches (browser
bridges, phone vibration, back button, render quality).

## Build

```sh
tools/build_android.sh                      # debug-signed APK, for testing
tools/build_android.sh release              # release template, signed with your keystore
```

First run installs the Android export templates for Godot 4.7.2 (about 1.3 GB), a debug keystore
and, when `ANDROID_ACCEPT_LICENSES=1` is set, the Android SDK (platform 35, build-tools 35.0.1; this
accepts Google's SDK licence). JDK 17 or newer is required. The result is `build/android/initialsj-debug.apk`
(about 37 MB). Install it on a phone with USB debugging: `adb install -r build/android/initialsj-debug.apk`,
or copy the file to the phone and open it (allow installs from that source).

## Build and upload to Dropbox

The APK is built on a machine you control, never in GitHub Actions (the repository has no APK
workflow). `tools/publish_apk.sh` does the whole job: it installs the pinned Godot engine when it is
missing (checksum-verified), imports the project, runs `tools/build_android.sh` and uploads the result
with `tools/upload_dropbox.py`.

```sh
ANDROID_ACCEPT_LICENSES=1 tools/publish_apk.sh     # test-signed APK -> Dropbox /initialsj/initialsj-test.apk
INITIALSJ_KEYSTORE=~/initialsj-release.keystore INITIALSJ_KEY_ALIAS=initialsj INITIALSJ_KEY_PASSWORD=... \
  ANDROID_ACCEPT_LICENSES=1 tools/publish_apk.sh release   # release APK -> /initialsj/initialsj-release.apk
tools/publish_apk.sh --no-upload                   # build only (also INITIALSJ_NO_UPLOAD=1)
```

`ANDROID_ACCEPT_LICENSES=1` is only needed while the Android SDK is not installed yet (it accepts
Google's SDK licence). A first run downloads about 1.5 GB; a repeat run takes a few minutes.

The upload reads three environment variables and never stores them in the repository:

| Variable | Meaning |
| --- | --- |
| `DROPBOX_APP_KEY`, `DROPBOX_APP_SECRET` | The Dropbox app that owns the upload (App Console > Settings). The app needs the `files.content.write`, `sharing.write` and `sharing.read` scopes (enable them on the Permissions tab before creating the token). |
| `DROPBOX_REFRESH_TOKEN` | A long-lived refresh token for that app, created once with `token_access_type=offline`. The script trades it for a short-lived access token on every run. |
| `DROPBOX_ACCESS_TOKEN` | Optional replacement for the three above: a ready access token, for a quick manual run. |

The file is replaced in place under the same name, so the shared link printed at the end
(`...?dl=1`, a direct download) stays valid for every later build. Upload only verified builds: the
script compares Dropbox's content hash with the local file before it prints the link. Use
`python3 tools/upload_dropbox.py FILE --no-link` if the app has no `sharing.write` scope. In the network
policy of a cloud session, allow `dl.google.com` (Android SDK), `api.dropboxapi.com` and
`content.dropboxapi.com`; the export templates and the engine come from github.com.

The test-signed and the release-signed APK use different keys and cannot update each other, so install
only one kind per phone. The rules for AI assistants that run this flow are in [AGENTS.md](../AGENTS.md).

## Settings

| Setting | Value |
| --- | --- |
| Package | `io.github.obmaz.initialsj` (change `package/unique_name` before publishing under your own id) |
| Name / icon | `Initial SJ Coast Rush`; icons in `assets/android/` (made by `tools/bake_android_icons.py`, adaptive icon with a flat dark background) |
| CPU | `arm64-v8a` only. Add `armeabi-v7a` in the preset if you need old 32-bit phones |
| Textures | ETC2/ASTC (`vram_texture_compression/for_mobile=true`, `for_desktop=false`), so the APK carries only the mobile format |
| Orientation | landscape (from `project.godot`), immersive mode on |
| Permissions | `VIBRATE` only (phone vibration for hits, landings and boosts). No internet |
| Renderer | GL Compatibility; graphics start on the web-like AUTO level (shorter shadows, 1600x900 cap) |
| Version | `version/code` 1, `version/name` 1.0: raise `version/code` for every update |

## Release signing

The test APK uses a public test key and must not be published to a store. A release APK or an app bundle for Google Play must be signed with a key only you hold. Create it
once and keep it outside the repository (never commit it):

```sh
keytool -genkeypair -v -keystore ~/initialsj-release.keystore -alias initialsj -keyalg RSA -keysize 2048 -validity 10000
INITIALSJ_KEYSTORE=~/initialsj-release.keystore INITIALSJ_KEY_ALIAS=initialsj INITIALSJ_KEY_PASSWORD=... tools/build_android.sh release
```

Losing that keystore means you can no longer update the app under the same id.

## What is and is not verified

The APK is built, aligned and signature-checked here, and its manifest was inspected (package,
permission, ABI). It has not been run on a device or emulator in this environment, so touch
controls, the Android back button, performance, vibration and audio on real phones still need a
device test. Browser-only features (install prompt, fullscreen button, Web Audio bridge) are not
used in the app.
