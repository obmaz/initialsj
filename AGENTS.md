# Project working scope

- Every commit must use `obmaz <zambobmaz@gmail.com>` for both author and committer. Set this identity explicitly for API-created commits; local Git configuration does not control GitHub API attribution.

- Repository and Pages: `obmaz/initialsj`, `https://obmaz.github.io/initialsj/`.
- The Godot project is at the repository root. Active modes are TOUR, Fuji TRACK01, SUNCOAST SPEEDWAY TRACK02, and MIDNIGHT HARBOR TRACK03 (night).
- Product names and signs are fictional. Keep the speedway's real-world inspiration out of game lettering.
- Use Godot **4.7.2** through `./tools/godot`. `.godot-version` and `tests/verify_engine.gd` enforce the engine version.
- Every vehicle owns its engine, boost, boost-start and drift sounds; never share or copy another vehicle's files. When adding, renaming or retuning a vehicle, follow `docs/VEHICLE_AUDIO.md` (catalog `audio` block, `tools/bake_vehicle_audio.py` recipe, import sidecars, provenance, docs); `tests/vehicle_audio_checks.gd` enforces it.
- Keep current documentation in README and `docs/`. Put generated reports, metrics and screenshots under ignored `build/reports/`; do not commit one-off review artifacts.
- Remove superseded source and resources with their `.uid`/`.import` sidecars after checking runtime and test references. Keep font/audio licenses and asset provenance current.
- The Android APK is never built by GitHub Actions. Build it locally and upload it to Dropbox with `tools/publish_apk.sh` (skill `android-apk`, `docs/ANDROID.md`) only when the user asks for an APK; Dropbox credentials come from the `DROPBOX_*` environment variables and are never printed or committed.
- Preserve `web/retire-flutter-worker.js`: deployment serves it at the old worker URL so returning browsers can release cached Flutter deployments.
- The user has authorized iterative reviews, fixes, useful generated artwork, pushes, and Pages deployment. Carry verified feature batches through deployment.
