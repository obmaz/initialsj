# Project working scope

- Repository and Pages: `obmaz/initialsj`, `https://obmaz.github.io/initialsj/`.
- The Godot project is at the repository root. Active modes are TOUR, Fuji TRACK01, and SUNCOAST SPEEDWAY TRACK02.
- Product names and signs are fictional. Keep the speedway's real-world inspiration out of game lettering.
- Use Godot **4.7.2** through `./tools/godot`. `.godot-version` and `tests/verify_engine.gd` enforce the engine version.
- Keep current documentation in README and `docs/`. Put generated reports, metrics and screenshots under ignored `build/reports/`; do not commit one-off review artifacts.
- Remove superseded source and resources with their `.uid`/`.import` sidecars after checking runtime and test references. Keep font/audio licenses and asset provenance current.
- Preserve `web/retire-flutter-worker.js`: deployment serves it at the old worker URL so returning browsers can release cached Flutter deployments.
- The user has authorized iterative reviews, fixes, useful generated artwork, pushes, and Pages deployment. Carry verified feature batches through deployment.
