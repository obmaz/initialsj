# Environment assets

The asphalt, dirt shoulder, grass, Fuji/lake panorama and distant mountain atlas are generated for this project. Original generation outputs remain in the local `generated_images/` workspace; they are not part of the deployment.

Roads, shoulders, guardrails, tunnels, trees, trackside props and the urban skyline use actual 3D geometry. Mountain panoramas and distant natural ridges provide horizon backdrops. Runtime sources are in `scripts/road_section.gd`, `scripts/roadside_geometry.gd`, `scripts/regional_props_3d.gd`, `scripts/road_biome.gd`, `scripts/circuit_environment.gd` and `scripts/speedway_environment.gd`.

The Fuji Lakeside sky uses three panels at the same pixel scale (about 14.8 pixels per degree), so nothing is stretched: the generated `fuji-lake-panorama.png` covers the 120 degrees around Mount Fuji, and `fuji-lake-back-a.png` / `fuji-lake-back-b.png` cover the remaining 240 degrees. The rear panels are baked from the panorama by `tools/bake_fuji_backdrop.py` (deterministic): the original water, shore and sky are reused 1:1 (mirror-joined only beside the seams, translated elsewhere so no symmetric pattern shows), the sun and Fuji are not repeated, and two new ridge lines are painted with the original forest's leaf detail. `shaders/fuji_sky.gdshader` joins the panels without mipmaps, because the sky is only ever magnified on screen.

No downloaded photographs or original arcade-game assets are used for the current scenery.

## 장대교·협곡과 가상 광고

`scenic_landmarks.gd`의 현수교와 층상 절벽은 이 프로젝트에서 직접 만든 절차적 3D 메시입니다. `ad-aerova.svg`, `ad-shift.svg`, `ad-fizz.svg`, `ad-apex.svg`는 가상 브랜드 광고이며 `tools/bake_scenic_ads.py`로 만듭니다. 번들 Roboto Bold Italic 글꼴(Apache-2.0, `assets/fonts/Roboto-LICENSE.txt`)의 윤곽선을 사용합니다. 외부 게임의 구조물·광고·상표를 추출하거나 복사하지 않았습니다. 광고판은 주행로 밖에 고정한 실제 패널이며 카메라를 따라 회전하지 않습니다.
