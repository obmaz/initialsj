# Open-road tour: implementation and review

Current behavior is the five-stage Coast Rush tour. Earlier Fuji/lap-racing screenshots and benchmark files in this folder are historical and do not describe the current game.

## Geometry and depth

`route_library.gd` defines eight themes across 15 nodes in five rows. Each selected section has two physical preview roads, and a left/right fork chooses the next node. The selected route contains approximately 7.9 km. Sections rise 12–28 m above their entry elevation, with the surface, cars and camera following the grade. Junction transitions project the player's world position onto the chosen branch; distance never wraps into a lap.

`road_biome.gd` builds real geometry: palms and sea in Hawaii; dunes and pyramids; windowed city buildings; an observation tower for Seoul; broken blocks and rubble; an animated Ferris wheel and tents; basalt rocks and wind turbines for Jeju. These are thematic stylizations rather than geographic reproductions. Every section includes a transparent framed canopy and an arch tunnel. Large props begin beyond the shared fork area; the unselected branch's terrain is disabled after commitment to prevent terrain covering the selected road.

Procedural geometry uses batched instances. Generated asphalt and ground source textures from the previous prototype are retained. The previous Fuji image panorama and billboard trees are preserved as source assets but are not active scenery in this tour.

## Driving and impact feedback

GAS accelerates to 288 km/h; fully established slipstream raises the cap to 316.8 km/h. BRAKE overrides GAS and can stop the car. A short brake tap while steering, followed by gas, initiates a latched drift. Space/DRIFT provides a shortcut. Drifting retains entry momentum without adding acceleration. Excess corner demand reduces steering authority and pushes the car outward; shoulder use and guardrails cost speed.

The car contact test uses oriented rectangular footprints, including drift angle. Resolution separates bodies in world space, respects the player's rail boundary, exchanges relative longitudinal speed and applies sideswipe slowdown. Sparks originate at the contact side, accompanied by camera shake, body recoil, a short screen flash and file-backed impact sound. Fixed particle pools keep bursts bounded.

At high speed, the camera widens, nearby scenery moves quickly, an edge blur and speed lines appear, and ambient particles change by theme. Tire smoke, live fading skid marks and brake lights respond to driving. M/reduced-motion settings disable blur, speed lines and extra camera motion. Reduced motion uses fewer collision sparks.

## Verification

- `tests/race_test.gd`: open road, real fork, elevation, eight themes, acceleration, gas/brake priority, brake-tap drift, grip release, oriented contacts, rails, checkpoint bonus/world-position continuity, five-stage finish, time expiry and resized simultaneous touch targets.
- `tests/contact_review.gd`: independently intersects world-space car polygons after actual collision resolution on four road locations, three lane positions and multiple drift/traffic angles. 144 overlapping contact cases; last reviewed maximum residual polygon intersection: 0.002 m², below 0.03 m² tolerance.
- `tests/tour_review.gd`: deterministic skilled controllers clear left, right and mixed routes; gas-only controller fails. Raw results: `tour-metrics.json`. These are simulations, not human difficulty measurements.
- `tests/keyboard_review.gd`: actual input events for W gas, S brake and brake-tap drift; `keyboard-metrics.json`, `tour/keyboard-drift.png`.
- `tests/preview_tour.gd`: rendered fixtures of all eight themes, canopy, tunnel, fork, elevation, drift, impact and speed. These are controlled visual fixtures, not screenshots of a completed human run.
- `tests/audio_review.gd`: records the actual native mixer and checks audibility, clipping, active silent gaps and mute. Graphical display required.
- `tests/web_audio_review.cjs`: Chromium/Playwright drives the exported game, records Web Audio and checks two native looping recording sources plus browser errors. Set `INITIALSJ_REVIEW_URL` for the deployed game.

Native visual checks:

```sh
DISPLAY=:99 godot --path new --script res://tests/preview_tour.gd --audio-driver Dummy
DISPLAY=:99 godot --path new --script res://tests/keyboard_review.gd --audio-driver Dummy
DISPLAY=:99 godot --path new --script res://tests/audio_review.gd --audio-driver Dummy
```

The environment uses Mesa software rendering. Its frame rate is not representative of a player's GPU. Real phones still need performance and handling review. Godot version tested: 4.6.3, not 4.7.2.
