# Project working scope

- Keep the repository and Pages address as `obmaz/initialsj` and `/initialsj/`.
- The Godot project is at the repository root. Legacy Flutter source and the version launcher have been removed.
- Active gameplay development targets TOUR, Fuji (TRACK 01), and SUNCOAST SPEEDWAY (TRACK 02).
- The user replaced the stopped Seocho prototype with an original Daytona-inspired tri-oval for TRACK 02. Use SUNCOAST SPEEDWAY branding; do not put the real circuit name on game screens or signage.
- Shared engine changes may naturally affect existing courses. Existing project-wide checks may still run to verify shared changes.
- The user has authorized iterative review, fixes, useful image generation, intermediate pushes, and Pages deployment.

- Use Godot **4.7.2** for development, checks, and Web export. The pinned launcher is `./tools/godot`; `tests/verify_engine.gd` rejects other engine versions.
