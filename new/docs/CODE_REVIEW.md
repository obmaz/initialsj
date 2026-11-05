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
- Three-card selection and start hit regions verified at 1280×720, phone landscape 896×414, and portrait 390×844. Selection is blocked during a tour.
- `race_test.gd` runs the shared `garage_checks.gd` regression suite, so the existing CI checks include these cases without changing root workflows.
- Existing world-space collision review passes 144 cases, maximum residual overlap 0.002 m².
- Scripted driving finishes the hardest all-right route with each car. These are controller simulations, not human playtest times; see `tour-metrics.json`.
- Native keyboard and exported Chromium touch checks cover selection and driving. Browser emulation does not establish physical-phone performance.

## Four-ability revision

Vehicle cards now compare exactly top speed, acceleration, boost and handling on a common ten-point scale. Nitro activation/resource types remain separate. Armor and per-car impact-loss multipliers were removed; collision tests now require equal speed loss for identical impacts. The ability bars derive speed, acceleration and boost from driving parameters, with handling using the existing profile rating.
