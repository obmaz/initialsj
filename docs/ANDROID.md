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

## Download

The APK is built only when you start it by hand: **Actions > Build Android APK > Run workflow**
([build-apk.yml](../.github/workflows/build-apk.yml)). The normal web deploy does not build it.

| Input | Meaning |
| --- | --- |
| `build_type` | `debug` (default) is signed with the shared test key `tools/android-test.keystore`, whose password is in the repository, so it is for test installs only and newer builds install over older ones. `release` is signed with your own key from repository secrets (see below). |
| `publish` | On (default): also publishes the file as a public release: test builds go to the `apk-test` release as `initialsj-test.apk`, release builds to `apk-release` as `initialsj-release.apk` (each tag points at the commit that built it). The two keys cannot update each other, so install only one kind per phone. Newest test build: <https://github.com/obmaz/initialsj/releases/download/apk-test/initialsj-test.apk>. Off: the APK is only kept as a workflow artifact for 30 days (sign-in required to download). |

The workflow must be started from the `main` branch (other branches stop with a message). The first link works only after the workflow has run once. A run takes about 6-10 minutes.

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

To build the release APK in GitHub Actions, add three repository secrets (Settings > Secrets and variables > Actions):
`ANDROID_KEYSTORE_BASE64` (output of `base64 -w0 ~/initialsj-release.keystore`), `ANDROID_KEY_ALIAS` and
`ANDROID_KEY_PASSWORD`, then run the workflow with `build_type` = `release`.

## What is and is not verified

The APK is built, aligned and signature-checked here, and its manifest was inspected (package,
permission, ABI). It has not been run on a device or emulator in this environment, so touch
controls, the Android back button, performance, vibration and audio on real phones still need a
device test. Browser-only features (install prompt, fullscreen button, Web Audio bridge) are not
used in the app.
