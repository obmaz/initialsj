# Modes and shared-model garage

The home screen offers TOUR, TRACK and Settings. Both modes enter the same garage and use the same driving controls. Settings provide sound, reduced motion and a concise control reference; preferences are stored in `user://settings.cfg`.

TOUR retains five open-road stages, different left/right destinations and checkpoint timing. TRACK restores the original Fuji lakeside environment and its continuous loop, with elevation, seven opponents and three laps. Track opponents never recycle; unwrapped progress determines rank while periodic world-space gaps handle collisions with lapped cars. There is one circuit and no Tour deadline in Track.

The garage shows one large vehicle and four performance bars. A single factory creates the exact same model, paint and nitro color for driving and showroom renders. Higher-resolution MSAA previews use a simple lit scene with a soft ground shadow; each model renders once on first selection and its texture is reused. The underlying race HUD is hidden behind home/garage screens. Three tabs change the selected car.

| Vehicle | Cruise km/h | Base acceleration m/s² | Boost km/h | Handling / 10 |
| --- | ---: | ---: | ---: | ---: |
| Nimori H | 259.2 | 28 | 313.2 | 10 |
| Veltrix S | 331.2 | 17 | 403.2 | 6 |
| Ironvale V8 | 288.0 | 34 | 360 / 388.8 cell | 4 |

These are arcade tuning values, not specifications for real cars. The ability bars derive speed, acceleration and boost from shared ranges; handling reflects steering/grip tuning. Nimori favors forgiving cornering and a rechargeable gauge; Veltrix trades launch and handling for speed and powerful shots; Ironvale trades steering response for launch power and hybrid nitro. Collision loss is common across cars.

Drift recovery now follows regained grip and unwound steering, so gentle curved sections do not hold an unnecessary drift indefinitely. Circuit AI corners with a modest grip allowance over the selected car's normal grip, rather than receiving full drift grip while always accelerating. Raw scripted driving results are in `circuit-metrics.json` and `tour-metrics.json`; they are not human playtests.

Records use `coast_rush_v3`, separated by mode and car. Older v2 records are preserved. The driving HUD reduces the permanent route list to a small current-region badge; next destinations appear only near a fork, with overtakes subdued beside score. Track uses position, lap count and a circuit map.

`race_test.gd` includes garage and mode regression checks. `modes_checks.gd` covers menu/settings touch navigation, mode switching, loop continuity, three-lap finish, lapped-car separation and record isolation. `circuit_drive_review.gd` drives all three vehicles through a complete race and checks that opponents never teleport. Existing real keyboard and exported-browser tests cover entry through the new home screen.

![Fuji circuit](fuji-circuit-80.png)

CPU traffic now previews the braking distance to a slower car and rechecks an occupied merge path every tick. These checks use wrapped physical gaps on the circuit, so a car on another lap still blocks an unsafe merge or approach. Stationary traffic cannot move sideways. Sustained pack results are in `traffic-metrics.json`; targeted queue and merge regressions are included by `race_test.gd`.

## Race feedback pass

TRACK displays small projected place badges over nearby cars, limited to three and omitted when they overlap or crowd the main HUD. All eight drivers have unique places even when two grid-row distances match; ties use a stable grid order. Physical lap-wrapped proximity chooses visible badges, while total race progress determines their displayed place. TOUR keeps traffic free of race-place badges.

A visible pause button sits beside the time panel; the full time panel remains tappable. Circuit pause titles and headers identify the race correctly. Touch devices receive a tap-to-resume message and touch control references. `modes_checks.gd` verifies unique grid places and pause/resume touch handling, and the exported-browser touch review captures a real mobile pause dialog.

Drift trails now use the current road width instead of a fixed lane offset, keeping tire marks on wide outer lanes. `feedback_visual_review.gd` captures badges, phone layouts, the circuit pause dialog and wide-road trails. These are rendered review fixtures.
