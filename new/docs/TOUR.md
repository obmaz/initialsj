# Coast Rush route revision

The current game is a five-stage branching open-road tour with a white AE86 Trueno-style player car. Older Fuji/circuit documentation and earlier route screenshots are historical.

## Longer roads with changing width

Sections now span 3,000–4,360 m, replacing the earlier 1,600 m sections. A full selected route covers approximately 16.7–18.3 km. Road width varies smoothly within a section, approximately 12.4–22.6 m overall. Junctions return to the same 18 m width to preserve continuity.

The asphalt mesh, lane paint, curbs, guardrails, roadside props, terrain edges, tunnel shell, traffic lane choices and player collision boundaries all use the same width function. Width changes affect actual driving and passing space. Terrain rises 28–64 m depending on the section.

Each right choice increases the route node: subsequent roads become longer, narrower and more curved, traffic grows denser, and checkpoint extensions shrink. Initial traffic is eight vehicles; the hardest final route has sixteen. Right-hand difficulty does not alter the player's physics or teleport opponents. Map colors indicate increasing risk to the right. Route progress runs from the bottom upward; a physical right turn moves upward and right on the map.

## Roofs and tunnels

Glass canopies appear at just two of the fifteen route nodes: a 96 m amusement section and an 84 m late Jeju section. The starting coast is open sky. Tunnels are selected by theme rather than repeated at the same place in every section. City tunnels are 950 m, Seoul tunnels 1,100 m; other selected themes have shorter passages.

A continuous arched mesh follows road curvature, grade and changing width. Emissive light strips, limited local lights and the AE86's forward spotlight provide visibility. The headlight turns on inside a tunnel. The tunnel's entrance sign states its length.

## City variety

Six archetypes use batched geometry: low brick blocks, glass high-rises, stepped towers, round towers, medium-rise offices and low commercial buildings. Heights, footprints, facade colors, window spacing, roof equipment and podiums vary. Ruined variants retain broken tops and window openings. Seoul keeps an open sightline toward its hilltop observation tower.

## Situational effects and nitro

Normal driving emits no pollen, dust or confetti. Tire smoke is limited to drifting, sparks to collisions, celebration confetti to one-shot checkpoint/goal events, and the blue exhaust effect to active nitro. Reduced motion disables celebrations, scenery blur, speed lines and extra camera motion; collision sparks use fewer particles.

GAS reaches 288 km/h; slipstream reaches 316.8 km/h. NITRO/Shift accelerates up to 345.6 km/h. Nitro also presses gas, so a touch player can steer with one thumb and move the other from GAS to NITRO. BRAKE overrides both. Nitro does not activate during drifting or an impact. Fuel drains at 20 units/s, regenerates at 3 units/s normally or 8 while drifting, and receives close-pass/checkpoint rewards. Empty fuel locks until 12 units recover, preventing repeated tiny pulses.

Starting time is 70 s. Checkpoints add 60 minus twice the accumulated number of right choices: 52–60 s. Finish and timeout end the tour without wrapping into laps.

## Review evidence

- `tests/race_test.gd`: open roads, fork/world-position continuity, actual changing mesh widths, upward map orientation, nitro acceleration/fuel/brake override/lockout, sparse canopies, long tunnel coverage, denser hard-route traffic, road difficulty and resized touch controls.
- `tests/contact_review.gd`: independent world-space polygon intersections after actual collision resolution on bends, across lane positions and drift angles.
- `tests/tour_review.gd`: the same skilled controller drives left, right and mixed routes using braking, drifting and planned nitro. The latest runs finish in 204.18, 274.27 and 222.07 s respectively; remaining time is 105.82, 15.73 and 79.93 s. The gas-only controller times out in stage two. These are deterministic simulations, not human playtest timings. Raw results: `tour-metrics.json`.
- `tests/keyboard_review.gd`: real input events for gas, braking, brake-tap drift and Shift nitro.
- `tests/preview_tour.gd`: controlled rendered fixtures; pass scene names after `--` to review selected views. New views include `long-tunnel`, `narrow`, `wide`, `city`, `canopy`, `speed` and `fork`.
- `tests/touch_review.cjs`: actual exported-game touch controls in Chromium's landscape phone emulation. It does not measure a physical phone.
- Audio remains imported OGG/WAV files with native browser looping; `tests/web_audio_review.cjs` can capture the deployed game via `INITIALSJ_REVIEW_URL`.

All source changes are under `new/`. Godot version verified is 4.6.3; 4.7.2 remains unverified. This workspace uses software rendering, so its frame rate does not represent a player's GPU. The older `render-metrics.json` records the earlier car batching review and is not a benchmark of this route revision.
