# Environment assets

The asphalt, dirt shoulder, grass, Fuji/lake panorama and distant mountain atlas are generated for this project. Original generation outputs remain in the local `generated_images/` workspace; they are not part of the deployment.

Roads, shoulders, guardrails, tunnels, trees, trackside props and the urban skyline use actual 3D geometry. Mountain panoramas and distant natural ridges provide horizon backdrops. Runtime sources are in `scripts/road_section.gd`, `scripts/roadside_geometry.gd`, `scripts/regional_props_3d.gd`, `scripts/road_biome.gd`, `scripts/circuit_environment.gd` and `scripts/speedway_environment.gd`.

The Fuji Lakeside sky uses three panels at the same pixel scale (about 14.8 pixels per degree), so nothing is stretched: the generated `fuji-lake-panorama.png` covers the 120 degrees around Mount Fuji, and `fuji-lake-back-a.png` / `fuji-lake-back-b.png` cover the remaining 240 degrees. The rear panels are baked from the panorama by `tools/bake_fuji_backdrop.py` (deterministic): the original water, shore and sky are reused 1:1 (mirror-joined only beside the seams, translated elsewhere so no symmetric pattern shows), the sun and Fuji are not repeated, and two new ridge lines are painted with the original forest's leaf detail. `shaders/fuji_sky.gdshader` joins the panels without mipmaps, because the sky is only ever magnified on screen.

No downloaded photographs or original arcade-game assets are used for the current scenery.

## 장대교·협곡과 가상 광고

`scenic_landmarks.gd`의 현수교와 층상 절벽은 이 프로젝트에서 직접 만든 절차적 3D 메시입니다. `ad-aerova.svg`, `ad-shift.svg`, `ad-fizz.svg`, `ad-apex.svg`는 가상 브랜드 광고이며 `tools/bake_scenic_ads.py`로 만듭니다. 번들 Roboto Bold Italic 글꼴(Apache-2.0, `assets/fonts/Roboto-LICENSE.txt`)의 윤곽선을 사용합니다. 외부 게임의 구조물·광고·상표를 추출하거나 복사하지 않았습니다. 광고판은 주행로 밖에 고정한 실제 패널이며 카메라를 따라 회전하지 않습니다.

## 구조물·표면 디테일

현수교는 테이퍼와 모서리가 있는 주탑, 콘크리트 기초, 원형 케이블, 별도 행거·접합판·가로보 보강재와 두께 있는 교량 바닥을 사용합니다. 광고판은 16×7m로 통일하며 42cm 두께의 뒷판, 금속 테두리, 후면 트러스·독립 기초·점검 발판·조명 하우징을 추가했습니다. 조명은 렌즈 재질로 표현하며 광고마다 동적 광원을 만들지 않습니다.

`generated-material-atlas.png`는 생성형 이미지로 만든 사암·노출 콘크리트·적색 도장 철골·아연도금 강판의 색상 아틀라스입니다. 밉맵·이방성 필터링·삼면 투영으로 경사면의 늘어짐을 줄입니다. 야자수는 연속 줄기·수피 마디와 잎맥·가느다란 소엽을 사용하며 기존의 개체별 폴리곤 예산 안에서 생성합니다.


## 생성형 재질 아틀라스

원본은 `exec-0121ba67-a9d9-4ae7-95ea-0d8ddd0af869.png`이며 로컬 `generated_images/`에 보존합니다. 배포본은 [generated-material-atlas.png](generated-material-atlas.png)입니다. 균일한 조명과 정면 투영, 무문자·무테두리의 네 가지 재질을 요청하여 생성했습니다. 좌상단은 사암, 우상단은 콘크리트, 좌하단은 적색 도장 철골, 우하단은 아연도금 강판입니다. 폴리곤은 추가하지 않았습니다.

금속·콘크리트 영역은 독립적으로 반복하고 경계를 여유 있게 샘플링하여 인접 재질이 섞이는 것을 줄입니다. 암석은 서로 반 주기 떨어진 샘플을 경계 가중치로 혼합하고 좌표를 약하게 왜곡하여 거울 반복의 대칭 무늬를 줄입니다. 암벽은 약 8.3m, 콘크리트는 약 5.6m, 철골·금속은 약 1~1.5m 표면 단위로 투영합니다. 원본은 색상 이미지이며 실측 PBR 자료가 아닙니다. 셰이더의 밝기 미분으로 약한 요철을 보조하고 거칠기·금속성은 재질 종류별로 지정합니다. 기존 절차적 사암 이미지와 생성 스크립트는 교체 후 제거했습니다.
