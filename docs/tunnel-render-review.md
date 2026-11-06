# Tunnel rendering review — 2026-11-06

## Corrected issues

- **P2: direction boards intersected the tunnel shell.** Exterior boards were placed perpendicular to travel, outside the wall. Underground boards now sit parallel to the inside wall with a physical gap; flags are omitted under the roof and along underpass retaining walls. This avoids masking the problem with render priority or depth-test overrides.
- **P3: local lights churned renderer visibility.** Every render frame previously disabled every lamp then re-enabled the nearest ones. A bounded nearest-six selection now changes only lamps whose visibility actually changes. Camera selection runs at roughly 16 Hz, while light rendering remains at the display refresh rate. Local lights retain disabled shadows and all three fixture families.
- **P3: the normal initial world frame never viewed a tunnel.** An opaque scene transition now renders five covered tunnel views once, preparing the Omni/Spot combinations before gameplay. The original camera, track visibility and physics-processing state are restored before reveal. This targets first-use shader preparation; it is not a measured Android FPS claim.

## Verification

Godot **4.7.2**, headless rules and native OpenGL Compatibility (Mesa llvmpipe):

- `tests/tunnel_render_checks.gd`: Fuji 9 wall-mounted boards, minimum sampled corner clearance **0.145 m**; Tour city tunnel 14 boards, **0.233 m**. Actual curved road alignment is sampled independently at board corners.
- Both cases: **0 visibility changes in 120 stationary updates**; 4 local lights active at the sampled midpoint, capped at 6 throughout the existing light-rig checks.
- `tests/tunnel_lights_checks.gd`: warm bulbs, cool strips, amber spotlights; all six-light and distance checks pass.
- `tests/tunnel_transition_review.gd`: native rendered transforms equal reviewed transforms; hidden warm-up remains under an opaque cover; camera and processing state restore correctly.
- Native screenshots: [Fuji underpass](tunnel-fixed-track.png), [Tour city tunnel](tunnel-fixed-tour.png).

The screenshots were inspected: direction boards remain readable on the interior face, with no wall intersection. A physical Android browser remains necessary to measure device-specific frame pacing.
