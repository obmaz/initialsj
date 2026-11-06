# Core gameplay review — 2026-11-05

Scope: `new/` race state, deadline/checkpoint ordering, focus/input handling, impacts, vehicle selection, three nitro resource models and exported web controls. `legacy/` and root workflows were not edited.

| Priority | Reproduced problem | Fix | Regression evidence |
| --- | --- | --- | --- |
| P2 | With 0.001 s left, 80 m/s speed and a checkpoint 0.2 m ahead, a 1/60 s step moved past the deadline and awarded 60 s. A finish could similarly count too late. | Limit simulation movement to the remaining time before resolving checkpoint/finish. A line genuinely reached before the deadline still counts. | `garage_checks.gd`: late checkpoint, late finish, valid last-instant checkpoint. Baseline printed `DEADLINE racing time 60.0 checkpoints 1`. |
| P2 | Losing focus during countdown left the state as `countdown`; it could enter a timed race in the background. | Pause both countdown and racing, preserve the phase, clear touch holds and resume the saved phase. Touch pause and P/Esc use the same helpers. | Countdown at 2 s remains frozen after focus loss; resume continues at 1.5 s after a 0.5 s step. Baseline printed `FOCUS countdown`. |
| P3 | Impact cleared `nitro_active` but left `boosting`, producing stale slipstream/FOV feedback after a nitro crash. | Cancel boost, burst and pending requests synchronously; prevent draft boost during an impact. | Impact during hybrid overdrive immediately clears both gameplay and feedback state without refunding a cell. Baseline printed `IMPACT boosting true`. |

No P0/P1 issue was identified in this scoped review. This is not a claim that every code path is defect-free.

## Vehicle implementation checks

- Three real 3D bodies with fictional product names, separate acceleration, grip, steering, braking and best-time keys.
- Hold gauge, three edge-triggered prepaid shots, and gauge plus two independent overdrive cells. Holding cannot spend successive shots/cells. Brake/drift/impact cancels a burst without refund. Checkpoints restore one shot/cell up to capacity.
- Three-card selection and start hit regions are checked in supported landscape viewports (1280×720, phone 896×414 and wide 2340×1080). Portrait now shows a rotation guide and pauses an active countdown/tour. Selection is blocked during a tour.
- `race_test.gd` runs the shared `garage_checks.gd` regression suite, so the existing CI checks include these cases without changing root workflows.
- Existing world-space collision review passes 144 cases, maximum residual overlap 0.002 m².
- Scripted driving finishes the hardest all-right route with each car. These are controller simulations, not human playtest times; see `tour-metrics.json`.
- Native keyboard and exported Chromium touch checks cover selection and driving. Browser emulation does not establish physical-phone performance.

## Four-ability revision

Vehicle cards now compare exactly top speed, acceleration, boost and handling on a common ten-point scale. Nitro activation/resource types remain separate. Armor and per-car impact-loss multipliers were removed; collision tests now require equal speed loss for identical impacts. The ability bars derive speed, acceleration and boost from driving parameters, with handling using the existing profile rating.

## Road patch review — 2026-11-06

P3: rear-contact resolution retained old hard-coded 70/88 m/s ceilings. A boosted car hit from behind could suddenly slow to 88 m/s despite receiving forward impulse. Removed these downward clamps and added a 112 m/s regression case. Contact still separates bodies and cancels active boosts.

Road patches share their rendered placement with swept tire detection, including per-lap circuit coordinates. Brake and impact override automatic boost; wet-road effects recover and spawn only short entry sprays. CPU corner/traffic braking retains priority. See [road patch implementation and verification](ROAD_FEATURES.md).

## CPU traffic review — 2026-11-06

| Priority | Finding | Change | Verification |
| --- | --- | --- | --- |
| P2 | Following logic waited until 18 m regardless of closing speed. A CPU approaching a stopped queue at 80 m/s passed through the lead car. | Preview stopping distance over 170 m with a body-length margin and a lower safety deceleration than the available brake force. | The controlled three-second case went from nine overlapping frames to zero; the follower stops 7.73 m behind. Tour and lapped circuit traffic use the same rule. |
| P3 | A previously chosen merge continued while another car occupied its path; simultaneous merges could overlap. | Re-check the lateral sweep each tick, hold an unsafe move and request a new lane decision. | Moving blocked/simultaneous merge cases went from 26/27 overlapping frames to zero while retaining forward progress. |
| P3 | Lane movement did not depend on forward speed, so stopped cars could slide sideways. | Scale lane-change speed below 12 m/s. | A stationary car remains in its lane; normal-speed merges continue. |

`traffic_checks.gd` runs seven queue/merge cases in the normal CI entry point, plus stopped-car checks. `traffic_pack_review.gd` checks seven NPCs continuously for 150 simulated seconds under each vehicle profile. Complete Tour and Fuji drives are also rerun to check progress and race completion; these scripted controls do not substitute for human playtesting.

## HUD feedback review — 2026-11-06

P3: the touch pause region did not cover the full rendered time panel, and pause was discoverable only by knowing that the timer was a button. Match its bounds to the panel and add a visible pause target. Circuit pause text now identifies TRACK rather than TOUR, with touch-specific resume guidance.

P3: dynamic tire trails used a fixed 7.2 m lane cutoff despite variable road widths. Use the active road's half-width and a tire clearance; native wide-road and overhead captures confirm the paired trails are present on the outer lane.

Projected circuit place badges use a deterministic tie order so matched grid rows do not receive duplicate places. Badges are limited and screened for overlap. Existing mode checks now cover unique grid places and the new touch pause control.

## Fuji ridge / drift / lighting review — 2026-11-06

P2: brake canceled the entire drift immediately, discarding corner grip during tight-turn deceleration. Keep a controlled drift when braking with steering; an explicit second drift tap or braking with unwound steering ends it. Entry/exit taps are edge-triggered and have no hidden cooldown. New tests cover pre-steering arming, holding taps, immediate reuse, opposite-direction entry and brake recovery.

P3: collision orientation used a one-sided two-metre tangent and a sloped forward projection, while rendered cars use symmetric tangents. Newly added hairpin cases exposed up to 0.085 m² of residual world-space body overlap. Use the rendered symmetric lane tangent and a horizontal collision plane. Independent polygon intersections now pass 324 Tour/circuit cases, worst residual 0.002 m².

RPM now has a real segmented fill driven by the same idle/gear/redline calculation as audio pitch. The pause dialog drops key explanations. The 4.36 km circuit adds elevation, straights, turns of both signs and a real shaded tunnel; mode tests cover those broad course requirements and tunnel bounds. Updated record keys preserve old course times without comparing them with the new layout.
