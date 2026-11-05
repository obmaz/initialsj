# Game feel review — iteration 1–7

## Measured in deterministic headless simulation

- Clear-road 0–100 km/h: 1.400 s; 0–200: 2.783 s.
- Cruise: 244.8 km/h; nitro: 316.8 km/h. The chase camera remains 6.03 m from the player at maximum speed.
- A CPU changes lanes and passes a slower test vehicle within four seconds. A separate 300-second traffic simulation reports no CPU-to-CPU body overlap.
- 124 seconds of CPU simulation stays within lane and speed limits and uses a finite nitro reserve.
- A driver who follows one lane without nitro or drifting completes three laps in 84.33 s, placing sixth. A second simulated driver selects clear passing lanes and saves nitro until at least 180 km/h and 40% reserve; it finishes first in 80.88 s. These are balance scenarios, not measured human playtests.
- Reproduce the comparison with `godot --headless --path new --script res://tests/balance_review.gd`; raw output is `balance-metrics.json`.

Raw values: `game-feel-metrics.json`. Run `godot --headless --path new --script res://tests/feel_test.gd` to reproduce. The older constant-acceleration setup theoretically needed 4.63 s to reach 200 km/h (12 m/s²); it is an analytical baseline rather than a recorded prior playtest.

## Applied

- Stronger initial acceleration and nitro, smoothed steering and lateral momentum.
- Clean drift release mini-turbo; wall grinding does not charge the reward.
- Slipstream speed/nitro recovery and close overtaking rewards.
- Curves push the car outward; CPU cars compensate while planning their line.
- CPU traffic-aware lane selection, gap braking, corner-speed planning and exit boost. No distance teleporting or position-based speed boost.
- Player starts eighth; CPU and player share the 88 m/s hard speed cap.
- Lower, closer chase camera, speed-sensitive FOV, restrained road vibration, impact feedback and nitro kick. Follow smoothing uses the offset from the player so speed cannot create excessive camera lag.
- Edge speed streaks, blue nitro edge light, soft billboard tire smoke, tapered additive blue exhaust flames and soft outlet halos, turbo and near-miss callouts. A five-sample peripheral blur affects scenery before the HUD is drawn; reduced motion disables it.
- Corrected inside-out vehicle surfaces and added a beveled painted shell, rear vents, tapered diffuser, metal exhaust outlets and spinning five-spoke rims. Thin tail LEDs and restrained clearcoat refine the chase view.
- Impacts also slow the opponent. Engine playback stops on menus/mute and releases on scene exit. Web engine/tire loops use native AudioBufferSource looping; short cues use Godot sample playback, and native builds use stream playback.
- Recorded engine and tire loops are imported OGG files; impacts and short enveloped UI cues are WAV files. Runtime tone/noise synthesis was removed, including the continuous noise layer. V mutes sound; M reduces camera motion and streak effects, and browser reduced-motion preference is respected.
- Reflective curve chevrons provide roadside motion cues.
- Player tire trails follow the actual rear wheels during drifts, using one fixed 160-segment MultiMesh pool and fading after nine seconds. They reset between races.
- World-space rank tags select the nearest two visible opponents ahead while retaining their true race positions. Overtaking triggers a short POS outline, callout and audio cue; lap transitions have a short announcement and chime.
- The drift button fills a cyan/gold charge arc; releasing a gold charge awards mini turbo.
- Pulsing countdown, start tones and a short GO cue emphasize the launch. An empty nitro tank requires 8% charge to restart, avoiding repeated tiny activation kicks.

## Audio and roadside motion review

The native audio mixer is captured by `tests/audio_review.gd` with a graphical display and Dummy audio. It checks nonzero output, clipping, sustained silent gaps during active sound and silence after muting; results are saved to `audio-metrics.json`, with a WAV in `user://audio-review.wav`. For example: `DISPLAY=:99 godot --path new --script res://tests/audio_review.gd --audio-driver Dummy`. This is a native mixer-output test, not an assessment of speaker quality. Web voices bypass the Godot mixer, so Chromium Web Audio output is captured separately with MediaRecorder during the browser review. Run `node new/tests/web_audio_review.cjs` with Playwright installed and a local export served at port 8787; `INITIALSJ_REVIEW_URL` can target the deployed game.

Near-road trees, two batched red course-banner layers and a fixed 36-petal emitter provide additional motion cues. Petals remain in world space as the car passes them; reduced motion hides them. No generated environment images were replaced.

## File audio and menu correction

After the user reported crackling, replace the synthesized runtime loops with recorded engine and tire OGG loops and imported WAV effects. On Web, engine/tire recordings use native AudioBufferSource nodes with loop=true. Godot 4.6's sample backend restarts loops from main-thread ended callbacks; browser capture exposed gaps during rendering stalls, so continuous loops bypass that restart path. Pitch and gain use smooth AudioParam targets. Cues remain file-backed Godot sample voices. Engine pitch changes stay within a restrained range, tires are quiet and the continuous noise layer is removed. Browser capture after the fix reports zero silent 10 ms windows in the 10–40 s active interval, no clipping and a silent muted tail (`web-audio-metrics.json`). Source credits, licenses and processing notes are in `assets/audio/LICENSE.txt`; export includes these notices. UI tones are baked offline by `tools/bake_cues.py`.

The start/pause/finish card grows from 560×358 to 810×525 design pixels. The title grows from 46 to 62 px; main instructions from 17 to 23–24 px. Steering/boost and drift instructions use separate rows, including the 80 km/h threshold and gold-charge release hint. Sound and reduced-motion controls also work by touch. Native menu captures are `menu-ready.png`, `menu-paused.png` and `menu-finished.png`.

## Keyboard integration review

`DISPLAY=:99 godot --path new --script res://tests/keyboard_review.gd --audio-driver Dummy` sends real keyboard events through the scene rather than calling the simulation step directly. It verifies acceleration/boost, steering into a drift and releasing a charged drift into mini turbo. The corner capture is `feel-keyboard-corner.png`; observed flags and score are in `keyboard-metrics.json`. Timing and pose depend on rendering, so this is not a deterministic balance replay. A Chromium touch run at 896×414 also exercised steering and boost together with no page overflow or error output; see `feel-mobile.png`.

## Review discipline

Check actual rendering and input after simulation. Headless speed/rank metrics do not establish perceived excitement or real-device frame rate. Keep `legacy/` unchanged. Native captures `feel-0.png` through `feel-3.png` cover acceleration, boost, drifting and drift release. `feel-overtake.png` and `feel-final-lap.png` are controlled milestone-state captures; the full-race test separately verifies that lap announcements fire twice, with no extra notice after finishing. A local Chromium WebGL run reached active racing and exercised Shift, M and V with no browser/Godot error output. Software-rendered frame rate is not a measurement of real-device performance.
