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

## 지질·구조물 재질 변형

`generated-rock-variants.png`는 생성형 원본 `exec-80a6dc93-cad1-4e64-bd25-8786726df608.png`입니다. 좌상단 적색 층상 사암, 우상단 밝은 석회암, 좌하단 짙은 현무암, 우하단 분홍·자주색 퇴적암으로 색과 균열·층리 구조가 각각 다릅니다. 월드 위치로 정한 수백 m 지질 구간과 고도별 층리를 부드럽게 혼합합니다. 프레임·재시작마다 재질이 바뀌지 않습니다.

`generated-structure-variants.png`는 생성형 원본 `exec-3f9b182c-c71a-40b7-8bab-b4edda0225b8.png`입니다. 따뜻한 건조 콘크리트·차가운 풍화 콘크리트·청회색 도장 철판·아이보리 도장 철판 4종입니다. 기존 아틀라스의 적색 철골·아연도금 강판도 유지합니다. 간판마다 프레임·지지대·뒷판의 변형을 일관되게 선택하고, 동일 모델의 다른 개체에는 다른 재질을 적용합니다. MultiMesh custom data로 선택하므로 변형별 노드·폴리곤을 추가하지 않습니다. 원본은 `/workspace/generated_images/`에 보존하며 색상 이미지의 밝기 보정은 보조 요철일 뿐 실측 PBR 노멀 맵이 아닙니다.

## 건물 전용 외벽과 간판 디자인



간판은 SUMMIT TIRE, ROUTE 84, BLUEBAY, ORBIT AUTO를 추가해 8종입니다. 각 새 디자인은 사선·도로 차선·파도·궤도 그래픽과 별도 색상을 사용합니다. `tools/bake_scenic_ads.py`가 번들 Roboto 윤곽선으로 개별 SVG와 `ad-print-atlas.svg`를 생성하며 대형 협곡 간판과 일반 지역 간판에서 재사용합니다. 모두 가상 브랜드입니다.

건물 전용 정면 `building-front-elevations.png`와 측면 `building-side-elevations.png`는 각각 `exec-662a932d-5b8b-4067-b69c-1906b514bd9f.png`, `exec-848aea2a-7be2-456e-9b1a-5815401c15ca.png`에서 복사했습니다. 4×3 구성의 각 영역이 서로 다른 건물의 정면·측면에 대응합니다. 국수집·기념품점의 `restaurant-elevations.png`는 `exec-16d888b4-e4bc-4d2a-a0c7-8faaf1a6a180.png`의 2×2 전용 외벽입니다. 이미지 생성 도구로 제작한 원본이며 외부 사진·실존 브랜드를 입력하지 않았습니다. 이전 소매점·도시 공용 외벽 두 장은 이 전용 이미지로 교체했습니다.
