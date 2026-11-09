# Project working scope

- Every commit must use `obmaz <zambobmaz@gmail.com>` for both author and committer. Set this identity explicitly for API-created commits; local Git configuration does not control GitHub API attribution.

- Repository and Pages: `obmaz/initialsj`, `https://obmaz.github.io/initialsj/`.
- The Godot project is at the repository root. Active modes are TOUR, Fuji TRACK01, SUNCOAST SPEEDWAY TRACK02, and MIDNIGHT HARBOR TRACK03 (night).
- Product names and signs are fictional. Keep the speedway's real-world inspiration out of game lettering.
- Use Godot **4.7.2** through `./tools/godot`. `.godot-version` and `tests/verify_engine.gd` enforce the engine version.
- Every vehicle owns its engine, boost, boost-start and drift sounds; never share or copy another vehicle's files. When adding, renaming or retuning a vehicle, follow `docs/VEHICLE_AUDIO.md` (catalog `audio` block, `tools/bake_vehicle_audio.py` recipe, import sidecars, provenance, docs); `tests/vehicle_audio_checks.gd` enforces it.
- Keep current documentation in README and `docs/`. Put generated reports, metrics and screenshots under ignored `build/reports/`; do not commit one-off review artifacts.
- Remove superseded source and resources with their `.uid`/`.import` sidecars after checking runtime and test references. Keep font/audio licenses and asset provenance current.
- Preserve `web/retire-flutter-worker.js`: deployment serves it at the old worker URL so returning browsers can release cached Flutter deployments.
- The user has authorized iterative reviews, fixes, useful generated artwork, pushes, and Pages deployment. Carry verified feature batches through deployment.

# Android APK (local build, Dropbox upload)

- GitHub Actions never builds the APK. Build it only when the user asks for an APK or its Dropbox upload, on the machine running the session: `ANDROID_ACCEPT_LICENSES=1 tools/publish_apk.sh` (test-signed, uploaded to Dropbox `/initialsj/initialsj-test.apk`), `tools/publish_apk.sh --no-upload` (build only), or `tools/publish_apk.sh release` with `INITIALSJ_KEYSTORE`, `INITIALSJ_KEY_ALIAS` and `INITIALSJ_KEY_PASSWORD`. Settings, signing and the upload flow are in `docs/ANDROID.md`.
- `ANDROID_ACCEPT_LICENSES=1` accepts Google's Android SDK licence, so set it only because the user asked for the build. Never sign a release with the shared test key `tools/android-test.keystore`, and never commit a keystore.
- Dropbox credentials are the environment variables `DROPBOX_APP_KEY`, `DROPBOX_APP_SECRET` and `DROPBOX_REFRESH_TOKEN`. Never print, inspect or commit their values. `invalid_grant` from the upload means the refresh token is invalid or revoked: it must be created again with OAuth `token_access_type=offline` and the scopes `files.content.write`, `sharing.write` and `sharing.read`.
- A cloud session with a limited network policy needs `dl.google.com` (Android SDK), `api.dropboxapi.com` and `content.dropboxapi.com`; Godot and the export templates come from github.com. If a host is refused, ask for it through the environment tools instead of working around it.
- Build from a verified state (`python3 tools/verify_repository.py` and the checks in `docs/DEVELOPMENT.md` when code changed). Report the APK size, signing kind, Dropbox path and the printed `?dl=1` link. Claim a verified upload only if the script printed its "content hash verified" line, and do not claim the APK ran on a device unless someone tested it.
- If the upload folder, file names or scopes change, update `tools/upload_dropbox.py`, `tools/publish_apk.sh`, `docs/ANDROID.md` and this section together.

# Other AI assistants

`AGENTS.md` is the single source of project instructions. Tool-specific files only import it (`CLAUDE.md` for Claude Code, `GEMINI.md` for Gemini CLI); Codex and other tools that read `AGENTS.md` need nothing. Put new shared rules here, not in tool-specific files, skills or prompts.
