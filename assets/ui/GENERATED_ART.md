# Menu artwork

Current artwork uses saturated coastal colours, strong directional lighting and stylized 3D geometry. The loading scene is guided by renders of the actual fictional NIMORI, VELTRIX and IRONVALE models. Home and garage backgrounds contain no cars: the UI overlays cached renders from the same vehicle factory used in races. Fuji and Suncoast course images are concept illustrations; Midnight Harbor and Azure Riviera use screenshots of their actual game renders; road geometry and the minimap are generated separately by the game.

| Current asset | Original generation file |
| --- | --- |
| [Loading and engine splash](coast-rush-splash.png) | `exec-e1703f50-1054-4f9e-8e75-13ee0fa00d26.png` |
| [Home coast](home-coast.png) | `exec-83b2a747-ade7-4946-9dca-db44ebbc8894.png` |
| [Garage](garage-bay.png) | `exec-013bcb89-1cda-4f48-ab68-254e386b4aee.png` |
| [Fuji course card](course-fuji.png) | `exec-8be49d29-fe68-4ee5-94d1-43c803ed3ae1.png` |
| [Suncoast course card](course-speedway.png) | `exec-80a07cec-f581-4b02-b13d-d7cb3c6984e7.png` |
| [Midnight Harbor course card](course-night.png) | Screenshot of the game's own night render (no generated source) |

Original generated PNGs are preserved in the local ignored `generated_images/` workspace; approved copies live beside this document. No photographic images, real manufacturer logos or original arcade-game assets are composited into these backgrounds. Titles, buttons, performance bars and progress indicators are rendered separately for readable mobile layouts.

## Game logo

[initialsj-logo.svg](initialsj-logo.svg) is the production vector wordmark, built by [`tools/bake_logo.py`](../../tools/bake_logo.py) from bundled Roboto Bold Italic outlines (Apache-2.0, see `assets/fonts`). It uses flat ivory/teal lettering, a small warm orange slash and a restrained subtitle. There are no chrome gradients, extrusions, outer strokes or glow. Letter outlines keep the brand identical in Godot and browsers without a system-font dependency.

Generated design studies (`exec-a4f09936-dfae-4bb5-97f5-04d1217b9d00.png` and `exec-fca7c290-c1f7-49bd-b5f3-aa88ac83ed51.png`) informed the flat colour direction; the final asset is clean vector typography rather than those raster studies. Original studies remain in the ignored `generated_images/` workspace. No real game or manufacturer logo is used.

The home screen and loading card use this SVG. The builder embeds the identical SVG between the `<!--logo:start-->` markers in `web/coast-rush-shell.html`, so it appears before any engine download without another request. Re-run `python3 tools/bake_logo.py` after changing the design (requires fontTools), and commit the SVG and shell together. The old raster logo is removed.

## AZURE RIVIERA 코스 이미지

[course-riviera.png](course-riviera.png)는 TRACK04의 실제 웹 주행 화면에서 HUD를 숨겨 직접 촬영했습니다. 프로젝트 자체 차량·해안·도로 리소스만 사용하며 외부 게임 화면이나 생성 이미지를 합성하지 않았습니다.

## SCARLET GORGE 코스 이미지

[course-gorge.png](course-gorge.png)는 TRACK05의 실제 웹 렌더에서 HUD를 숨겨 직접 촬영했습니다. 프로젝트 자체 차량·현수교·도로만 사용하며 외부 영상이나 게임 에셋을 합성하지 않았습니다.
