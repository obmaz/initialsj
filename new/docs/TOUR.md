# Coast Rush route revision

The current game is a five-stage branching open-road tour with three selectable original vehicle bodies: Nimori H, Veltrix S and Ironvale V8. Older Fuji/circuit documentation and earlier route screenshots are historical.

## Longer roads with changing width

Sections now span 3,000–4,360 m, replacing the earlier 1,600 m sections. A full selected route covers approximately 16.7–18.3 km. Road width varies smoothly within a section, approximately 12.4–22.6 m overall. Junctions return to the same 18 m width to preserve continuity.

The asphalt mesh, lane paint, curbs, guardrails, roadside props, terrain edges, tunnel shell, traffic lane choices and player collision boundaries all use the same width function. Width changes affect actual driving and passing space. Terrain rises 28–64 m depending on the section.

Each right choice increases the route node: subsequent roads become longer, narrower and more curved, traffic grows denser, and checkpoint extensions shrink. Initial traffic is eight vehicles; the hardest final route has sixteen. Right-hand difficulty does not alter the player's physics or teleport opponents. Map colors indicate increasing risk to the right. Route progress runs from the bottom upward; a physical right turn moves upward and right on the map.

## Roofs and tunnels

Glass canopies appear at just two of the fifteen route nodes: a 96 m amusement section and an 84 m container-port section. The starting coast is open sky. Tunnels are selected by theme rather than repeated at the same place in every section. City tunnels are 950 m, Seoul tunnels 1,100 m; other selected themes have shorter passages.

A continuous arched mesh follows road curvature, grade and changing width. Emissive light strips, limited local lights and each player's forward spotlight provide visibility. The headlight turns on inside a tunnel. The tunnel's entrance sign states its length.

## City variety

Six archetypes use batched geometry: low brick blocks, glass high-rises, stepped towers, round towers, medium-rise offices and low commercial buildings. Heights, footprints, facade colors, window spacing, roof equipment and podiums vary. Ruined variants retain broken tops and window openings. Seoul keeps an open sightline toward its hilltop observation tower.

## Situational effects and nitro

Normal driving emits no pollen, dust or confetti. Tire smoke is limited to drifting, sparks to collisions, celebration confetti to one-shot checkpoint/goal events, and the vehicle-colored exhaust effect to active nitro. Reduced motion disables celebrations, scenery blur, speed lines and extra camera motion; collision sparks use fewer particles.

The garage exposes exactly four abilities: top speed, acceleration, boost and handling. Its shared ten-point bars derive speed/acceleration/boost from actual driving values; boost rates nitro acceleration. Nitro resource type is a separate mechanic. Collision speed-loss factors are identical for all vehicles.

Vehicle profiles live in `vehicle_catalog.gd`: Nimori cruises at 273.6 km/h and boosts to 334.8; Veltrix cruises at 306 and fires 385.2 km/h shots; Ironvale cruises at 284.4, holds gauge boost at 331.2 and reaches 367.2 with a cell. Slipstream adds up to 28.8 km/h to cruise. Actual attained speed depends on acceleration, cornering and traffic.

Nimori holds Shift/NITRO to drain 19 fuel/s, recharging 3/s normally or 9/s drifting. Veltrix starts with three 2.4 s prepaid shots, triggered once per tap. Ironvale holds Shift for a 24 fuel/s gauge or presses E/CELL for an independent 1.6 s overdrive (two cells). Hybrid recharge is 2/s normally, 7/s drifting. Overdrive does not drain gauge fuel. Every checkpoint restores one shot/cell up to capacity and adds 25 gauge fuel; close passes add 12. Gauge lockout ends at 12 units.

Nitro also supplies gas for touch driving. BRAKE overrides it. Drift/impact cancels any running burst without refund. Holding a shot/cell never spends the next one automatically. Best-time keys are per vehicle, preserving existing record entries. The garage renders each model once in a separate viewport and reuses its texture.

Starting time is 70 s. Checkpoints add 60 minus twice the accumulated number of right choices: 52–60 s. Finish and timeout end the tour without wrapping into laps.

## Review evidence

- `tests/race_test.gd`: open roads, fork/world-position continuity, actual changing mesh widths, upward map orientation, nitro acceleration/fuel/brake override/lockout, sparse canopies, long tunnel coverage, denser hard-route traffic, road difficulty and resized touch controls.
- `tests/contact_review.gd`: independent world-space polygon intersections after actual collision resolution on bends, across lane positions and drift angles.
- `tests/tour_review.gd`: braking/drifting/planned nitro controllers finish left, right and mixed Nimori routes, and all-right routes in Veltrix and Ironvale. The gas-only controller times out in stage two. These are scripted simulations, not human playtest timings. Raw results: `tour-metrics.json`.
- `tests/garage_review.gd` / `garage_checks.gd`: three-car selection, resized touch regions, different acceleration and uniform collision loss, gauge/shot/hybrid resource rules, checkpoint refill and the P2/P3 regressions in [CODE_REVIEW.md](CODE_REVIEW.md). The main `race_test.gd` also invokes this suite for CI.
- `tests/keyboard_review.gd`: real input events for gas, braking, brake-tap drift and Shift nitro.
- `tests/preview_tour.gd`: controlled rendered fixtures; pass scene names after `--` to review selected views. New views include `long-tunnel`, `narrow`, `wide`, `city`, `canopy`, `speed` and `fork`.
- `tests/touch_review.cjs`: actual exported-game touch controls in Chromium's landscape phone emulation. It does not measure a physical phone.
- Audio remains imported OGG/WAV files with native browser looping; `tests/web_audio_review.cjs` can capture the deployed game via `INITIALSJ_REVIEW_URL`.

All source changes are under `new/`. Godot version verified is 4.6.3; 4.7.2 remains unverified. This workspace uses software rendering, so its frame rate does not represent a player's GPU. The older `render-metrics.json` records the earlier car batching review and is not a benchmark of this route revision.

## Fifteen distinct destinations

Every route node now has its own theme. All sixteen possible full tours visit five distinct themes, and every fork has different left and right destinations. [THEMES.md](THEMES.md) lists the complete map and generated roadside-art pipeline. The theme layout preserves route lengths and cumulative right-branch difficulty. Current vehicle tuning and deadline behavior are covered by the new tour metrics.
