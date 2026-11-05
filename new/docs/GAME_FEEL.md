# Game feel review — iteration 1–3

## Measured in deterministic headless simulation

- Clear-road 0–100 km/h: 1.400 s; 0–200: 2.783 s.
- Cruise: 244.8 km/h; nitro: 316.8 km/h. The chase camera remains 7.00 m from the player at maximum speed.
- A CPU changes lanes and passes a slower test vehicle within four seconds.
- 124 seconds of CPU simulation stays within lane and speed limits and uses a finite nitro reserve.
- A driver who follows one lane without nitro or drifting completes three laps in 84.33 s, placing sixth in the current deterministic grid. This is a balance scenario, not a measured human playtest.

Raw values: `game-feel-metrics.json`. Run `godot --headless --path new --script res://tests/feel_test.gd` to reproduce. The older constant-acceleration setup theoretically needed 4.63 s to reach 200 km/h (12 m/s²); it is an analytical baseline rather than a recorded prior playtest.

## Applied

- Stronger initial acceleration and nitro, smoothed steering and lateral momentum.
- Clean drift release mini-turbo; wall grinding does not charge the reward.
- Slipstream speed/nitro recovery and close overtaking rewards.
- Curves push the car outward; CPU cars compensate while planning their line.
- CPU traffic-aware lane selection, gap braking, corner-speed planning and exit boost. No distance teleporting or position-based speed boost.
- Player starts eighth; CPU and player share the 88 m/s hard speed cap.
- Lower, closer chase camera, speed-sensitive FOV, restrained road vibration, impact feedback and nitro kick. Follow smoothing uses the offset from the player so speed cannot create excessive camera lag.
- Edge speed streaks, blue nitro edge light, soft billboard tire smoke, tapered additive exhaust flames, turbo and near-miss callouts. A five-sample peripheral blur affects scenery before the HUD is drawn; reduced motion disables it.
- Corrected inside-out vehicle surfaces and added a beveled painted shell, rear vents and spinning rims.
- Impacts also slow the opponent. Engine playback stops on menus/mute and releases on scene exit. Explicit stream playback fixes the Web export’s unsupported sample-playback warning for generated audio.
- Synthesized engine, tire and wind sound. V mutes sound; M reduces camera motion and streak effects, and browser reduced-motion preference is respected.
- Reflective curve chevrons provide roadside motion cues.

## Review discipline

Check actual rendering and input after simulation. Headless speed/rank metrics do not establish perceived excitement or real-device frame rate. Keep `legacy/` unchanged. Native captures `feel-0.png` through `feel-3.png` cover acceleration, boost, drifting and drift release. Browser checks are also required; simulation results do not establish perceived excitement or real-device frame rate.
