# Project working scope

- Keep the repository and Pages address as `obmaz/initialsj` and `/initialsj/`.
- The Godot project is at the repository root. Legacy Flutter source and the version launcher have been removed.
- Active gameplay development targets TOUR and the Fuji circuit (TRACK 01).
- The user has said the Seocho circuit will be removed and explicitly asked for no further work on it. Do not modify dedicated Seocho source, data, assets, or prepare new Seocho images/reviews unless the user reopens that scope. Do not infer an instruction to delete it immediately from the work-stop request.
- Shared engine changes may naturally affect existing courses. Existing project-wide checks may still run to verify shared changes.
- The user has authorized iterative review, fixes, useful image generation, intermediate pushes, and Pages deployment.

- Use Godot **4.7.2** for development, checks, and Web export. The pinned launcher is `./tools/godot`; `tests/verify_engine.gd` rejects other engine versions.
