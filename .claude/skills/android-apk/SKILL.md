---
name: android-apk
description: Build the Initial SJ Android APK locally and upload it to Dropbox. Use only when the user asks for an APK build, a new test APK, or a Dropbox upload of the APK. GitHub Actions no longer builds the APK.
---

# Android APK: local build and Dropbox upload

The repository has **no APK workflow**. The APK is built on the machine running this session and the
result goes to Dropbox. Run it only when the user asks for an APK, not as a side effect of other work.

## Run

```sh
ANDROID_ACCEPT_LICENSES=1 tools/publish_apk.sh            # test-signed -> Dropbox /initialsj/initialsj-test.apk
tools/publish_apk.sh --no-upload                           # build only, keep build/android/initialsj-debug.apk
INITIALSJ_KEYSTORE=... INITIALSJ_KEY_ALIAS=... INITIALSJ_KEY_PASSWORD=... tools/publish_apk.sh release
```

The script installs the pinned Godot (`.godot-version`, checksum-verified) when `./tools/godot` is
missing, imports the project, runs `tools/build_android.sh` (export templates, Android SDK, signing)
and then `python3 tools/upload_dropbox.py`. A first run in a fresh container downloads about 1.5 GB
and takes 5-10 minutes; `ANDROID_ACCEPT_LICENSES=1` accepts Google's SDK licence for that install, so
set it only because the user asked for the build. The details are in `docs/ANDROID.md`.

## Before you start

1. **Credentials**: `DROPBOX_APP_KEY`, `DROPBOX_APP_SECRET` and `DROPBOX_REFRESH_TOKEN` must be set (the
   cloud environment stores them). Never print or inspect their values. The script reports a rejected
   token itself (`invalid_grant` = the refresh token is invalid or revoked; the user has to create a new
   one with `token_access_type=offline` and update the environment variable).
2. **Network** (cloud sessions with a limited policy): `dl.google.com` (Android SDK),
   `api.dropboxapi.com` and `content.dropboxapi.com`. Godot and the export templates come from
   github.com. If a host is refused, ask for it through the environment tools; do not work around it.
3. **Release signing** needs the user's own keystore, never the shared test key
   `tools/android-test.keystore` (its password is public). Do not commit keystores.
4. Build from a verified state: run the normal checks first if the code changed
   (`python3 tools/verify_repository.py` and the checks in `docs/DEVELOPMENT.md`).

## Report

State the APK size and signing kind, the Dropbox path, and the direct download link
(`...?dl=1`) printed by the upload. The script verifies Dropbox's content hash against the local file
before it prints the link, so say so only if that line appeared. If the upload fails, keep the built
file in `build/android/` (ignored by Git), say exactly which step failed, and do not retry with other
credentials or hosts. The APK has not been run on a device unless someone did it; do not claim it was.

## Maintain

If the upload folder, file names or required scopes change, update `tools/upload_dropbox.py`,
`tools/publish_apk.sh`, `docs/ANDROID.md` and this file together. Generated reports belong under the
ignored `build/reports/`.
