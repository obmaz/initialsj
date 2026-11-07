# Menu artwork

Current artwork uses saturated coastal colours, strong directional lighting and stylized 3D geometry. The loading scene is guided by renders of the actual fictional NIMORI, VELTRIX and IRONVALE models. Home and garage backgrounds contain no cars: the UI overlays cached renders from the same vehicle factory used in races. Course images are concept illustrations; road geometry and the minimap are generated separately by the game.

| Current asset | Original generation file |
| --- | --- |
| [Loading and engine splash](coast-rush-splash.png) | `exec-e1703f50-1054-4f9e-8e75-13ee0fa00d26.png` |
| [Home coast](home-coast.png) | `exec-83b2a747-ade7-4946-9dca-db44ebbc8894.png` |
| [Garage](garage-bay.png) | `exec-013bcb89-1cda-4f48-ab68-254e386b4aee.png` |
| [Fuji course card](course-fuji.png) | `exec-8be49d29-fe68-4ee5-94d1-43c803ed3ae1.png` |
| [Suncoast course card](course-speedway.png) | `exec-80a07cec-f581-4b02-b13d-d7cb3c6984e7.png` |

Original generated PNGs are preserved in the local ignored `generated_images/` workspace; approved copies live beside this document. No photographic images, real manufacturer logos or original arcade-game assets are composited into these backgrounds. Titles, buttons, performance bars and progress indicators are rendered separately for readable mobile layouts.

## Game logo

[initialsj-logo.png](initialsj-logo.png) is drawn procedurally by [`tools/bake_logo.py`](../../tools/bake_logo.py), not by an image model or from a photograph: Roboto Black Italic lettering (Apache-2.0, see `assets/fonts`) with a chrome gradient, outline, extrusion, glow, speed streaks and a checkered plate. It is a fictional wordmark and copies no real game or brand logo. The home screen and the loading card draw the PNG; the same script refreshes the small inline WebP copy between the `<!--logo:start-->` markers in `web/coast-rush-shell.html`, which the page shows while the download runs. Re-run `python3 tools/bake_logo.py` after changing the design and commit both outputs.
