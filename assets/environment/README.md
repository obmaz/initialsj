# 환경 에셋

노면·갓길·잔디·후지산과 호수 파노라마·원경 산맥은 이 프로젝트용으로 제작했습니다. 사용 중인 이미지의 생성 원본은 로컬 `generated_images/`에 보존하며 배포에는 포함하지 않습니다.

도로·가드레일·터널·나무·소품·건물은 실제 3D 형상이며, 산 파노라마와 원경 능선은 수평선 배경입니다. 모델별 형상은 `models/`가 소유하고 도로·배치는 `scripts/track/road_section.gd`, [world_assets.gd](../../scripts/rendering/world_assets.gd), [regional_props_3d.gd](../../scripts/environment/regional_props_3d.gd), [road_biome.gd](../../scripts/environment/road_biome.gd)와 코스별 GLB·조립 씬이 처리합니다. 독립 모델 제작 규격은 [MODEL_PIPELINE.md](../../docs/MODEL_PIPELINE.md)를 따릅니다.

후지 하늘은 약14.8픽셀/도의 같은 밀도로 세 패널을 연결합니다. `fuji-lake-panorama.png`가 후지산 방향120도, `fuji-lake-back-a.png`와 `fuji-lake-back-b.png`가 나머지240도를 덮습니다. `tools/bake_fuji_backdrop.py`는 원본의 물·해안·하늘을1:1로 재사용하고 원본 숲의 잎 디테일로 두 능선을 구성합니다. 태양·후지산은 반복하지 않으며 이음매 인근만 대칭 연결합니다. `shaders/fuji_sky.gdshader`는 확대되는 하늘에 맞춰 밉맵 없이 연결합니다.

현재 풍경에는 다운로드한 사진이나 원본 아케이드 게임의 에셋을 사용하지 않습니다.

## 장대교·협곡과 가상 광고

[scenic_landmarks.gd](../../scripts/environment/scenic_landmarks.gd)의 현수교와 층상 절벽은 이 프로젝트에서 직접 만든 절차적 3D 메시입니다. `ad-print-atlas.svg`의 가상 브랜드8종은 가상 브랜드 광고이며 `tools/bake_scenic_ads.py`로 만듭니다. 번들 Roboto Bold Italic 글꼴(Apache-2.0, `assets/fonts/Roboto-LICENSE.txt`)의 윤곽선을 사용합니다. 외부 게임의 구조물·광고·상표를 추출하거나 복사하지 않았습니다. 광고판은 주행로 밖에 고정한 실제 패널이며 카메라를 따라 회전하지 않습니다.

## 구조물·표면 디테일

현수교는 테이퍼와 모서리가 있는 주탑, 콘크리트 기초, 원형 케이블, 별도 행거·접합판·가로보 보강재와 두께 있는 교량 바닥을 사용합니다. 대형 광고판의 인쇄면은20×8.75m이며,1m 두께의 뒷판, 금속 테두리, 후면 트러스·독립 기초·점검 발판·조명 하우징을 사용합니다. 조명은 렌즈 재질로 표현하며 광고마다 동적 광원을 만들지 않습니다.

`generated-material-atlas.png`는 생성형 이미지로 만든 사암·노출 콘크리트·적색 도장 철골·아연도금 강판의 색상 아틀라스입니다. 밉맵·이방성 필터링·삼면 투영으로 경사면의 늘어짐을 줄입니다. 야자수는 연속 줄기·수피 마디와 잎맥·가느다란 소엽을 사용하며 기존의 개체별 폴리곤 예산 안에서 생성합니다.

## 생성형 재질 아틀라스

원본은 `exec-0121ba67-a9d9-4ae7-95ea-0d8ddd0af869.png`이며 로컬 `generated_images/`에 보존합니다. 배포본은 [generated-material-atlas.png](generated-material-atlas.png)입니다. 균일한 조명과 정면 투영, 무문자·무테두리의 네 가지 재질을 요청하여 생성했습니다. 좌상단은 사암, 우상단은 콘크리트, 좌하단은 적색 도장 철골, 우하단은 아연도금 강판입니다. 폴리곤은 추가하지 않았습니다.

금속·콘크리트 영역은 독립적으로 반복하고 경계를 여유 있게 샘플링하여 인접 재질이 섞이는 것을 줄입니다. 암석은 서로 반 주기 떨어진 샘플을 경계 가중치로 혼합하고 좌표를 약하게 왜곡하여 거울 반복의 대칭 무늬를 줄입니다. 암벽은 약 8.3m, 콘크리트는 약 5.6m, 철골·금속은 약 1~1.5m 표면 단위로 투영합니다. 원본은 색상 이미지이며 실측 PBR 자료가 아닙니다. 셰이더의 밝기 미분으로 약한 요철을 보조하고 거칠기·금속성은 재질 종류별로 지정합니다.

## 지질·구조물 재질 변형

`generated-rock-variants.png`는 생성형 원본 `exec-80a6dc93-cad1-4e64-bd25-8786726df608.png`입니다. 좌상단 적색 층상 사암, 우상단 밝은 석회암, 좌하단 짙은 현무암, 우하단 분홍·자주색 퇴적암으로 색과 균열·층리 구조가 각각 다릅니다. 월드 위치로 정한 수백 m 지질 구간과 고도별 층리를 부드럽게 혼합합니다. 프레임·재시작마다 재질이 바뀌지 않습니다.

`generated-structure-variants.png`는 생성형 원본 `exec-3f9b182c-c71a-40b7-8bab-b4edda0225b8.png`입니다. 따뜻한 건조 콘크리트·차가운 풍화 콘크리트·청회색 도장 철판·아이보리 도장 철판 4종입니다. 기존 아틀라스의 적색 철골·아연도금 강판도 유지합니다. 간판마다 프레임·지지대·뒷판의 변형을 일관되게 선택하고, 동일 모델의 다른 개체에는 다른 재질을 적용합니다. MultiMesh custom data로 선택하므로 변형별 노드·폴리곤을 추가하지 않습니다. 원본은 `/workspace/generated_images/`에 보존하며 색상 이미지의 밝기 보정은 보조 요철일 뿐 실측 PBR 노멀 맵이 아닙니다.

## 건물 전용 외벽과 간판 디자인

벡터 간판8종에는 SUMMIT TIRE, ROUTE 84, BLUEBAY, ORBIT AUTO 등이 있습니다. 디자인마다 사선·도로 차선·파도·궤도 그래픽과 별도 색상을 사용합니다. `tools/bake_scenic_ads.py`가 번들 Roboto 윤곽선으로 `ad-print-atlas.svg`의8개 인쇄 영역을 생성하며 대형 협곡 간판과 일반 지역 간판에서 재사용합니다. 모두 가상 브랜드입니다.

건물 전용 정면 `building-front-elevations.png`와 측면 `building-side-elevations.png`는 각각 `exec-662a932d-5b8b-4067-b69c-1906b514bd9f.png`, `exec-848aea2a-7be2-456e-9b1a-5815401c15ca.png`에서 복사했습니다. 4×3 구성의 각 영역이 서로 다른 건물의 정면·측면에 대응합니다. 국수집·기념품점의 `restaurant-elevations.png`는 `exec-16d888b4-e4bc-4d2a-a0c7-8faaf1a6a180.png`의 2×2 전용 외벽입니다. 이미지 생성 도구로 제작한 원본이며 외부 사진·실존 브랜드를 입력하지 않았습니다.

## 노면·잔디·갓길의 생성형 변형

`asphalt-variants.png`는 생성 원본 `exec-fef7bb7c-3ac9-4d45-b397-b8d9fff2d3b0.png`(1254×1254)의 2×2 아틀라스입니다. 좌상단부터 새 짙은 아스팔트, 마모된 회색, 햇볕에 바랜 따뜻한 노면, 차가운 보수 노면을 담습니다. `terrain-variants.png`는 원본 `exec-983c2897-5ddf-48e2-8690-2cc5058e99f3.png`(1774×887)의 4×2 아틀라스입니다. 왼쪽 두 열은 짧은 잔디·긴 풀·마른 풀·클로버, 오른쪽 두 열은 다진 흙·고운 자갈·모래 섞인 흙·어두운 부엽토입니다. 균일한 확산광, 수직 정면 표면, 무문자·무차선·무테두리를 요청한 생성형 색상 이미지이며 외부 게임 에셋을 입력하지 않았습니다. 원본을 리사이즈하거나 잘라내지 않고 셰이더에서 영역을 선택합니다.

`ground_variety.gdshaderinc`는 2.56m 표면 결을 서로 다른 회전·위상으로 샘플링하고, 약 14m·37m 분포와 125m 명암 변화를 혼합합니다. 반 주기 떨어진 두 표본의 경계 가중치로 타일 이음매를 줄입니다. 월드 좌표 기준으로 도로 구간이 바뀌어도 결이 이어지며, 미분값을 별도로 전달해 영역 전환 때 밉맵이 튀는 현상을 방지합니다. 두 원본은 VRAM 압축·밉맵·이방성 필터링을 사용합니다. 아스팔트 색상, 후지·스피드웨이 잔디, 해안·투어 지면과 갓길에 적용하며 기존 바위·모래·도시 포장 및 경사면 구분을 유지합니다. 실제 노멀·거칠기 촬영 자료로 간주하지 않습니다.

## 실척과 차량 비례

근거리 건물·나무·일반 광고판의 치수는 각 모델의 `definition.tres`에서 정하며 공통 모델 어댑터가 메시를 미터 기준으로 보정해 배치합니다. 편의점 약19×18m 부지, 주유소 약30×31m 부지, 야자수 약15m, 소나무 약19m, 종별CC0 성목14~24m를 사용합니다. 도로는 승용차 길이4.3m 기준을 유지하며 차도 밖 전체 반경으로 배치 여유를 계산합니다. 텍스처의 정면·측면 영역은 보존하고 비균일 크기 보정에 맞춰 법선을 역전치 변환합니다.

## 도시·항만·트럭·해안 하늘 추가 원본

`urban-harbor-facades.png`는 생성형 원본 `exec-cad2683c-4dc2-481d-a211-24b295d58741.png`의4×3 아틀라스입니다. 앞6칸은 벽돌·유리·아파트·보라색 타워·민트 오피스·사암 고전 외벽이고 뒤6칸은 서로 다른 야간 항만 창고입니다. `urban-truck-elevations.png`는 원본 `exec-fbfc42af-8f4d-4743-9b5f-c6fd166d364d.png`의4×3 아틀라스로, 앞6칸은 청록·테라코타·아이보리·차콜·분홍·황토의 추가 건물 외벽, 뒤6칸은 흰 트레일러 옆/뒤·파란 캐빈 앞/옆·적색 트레일러 옆/뒤입니다. 텍스처 영역만 셰이더에서 선택하며 원본을 잘라내거나 재편집하지 않았습니다.

`riviera-sky-panorama.png`는 생성형 원본 `exec-13deda8f-bac7-4414-8a83-12f783041785.png`의2:1 위경도 하늘입니다. 푸른 하늘과 구름만 요청했고 시선 경도/위도로 매핑해 정면 사진을 늘리는 왜곡을 피합니다. 세 원본은 이미지 생성 도구로 제작했고 외부 사진·게임 에셋·실존 브랜드를 입력하지 않았습니다. 생성 원본은 `/workspace/generated_images/`에 보존합니다.

`container-elevations.png`는 생성형 원본 `exec-c5fc9002-63b1-4504-8330-3a79c929197e.png`의4×2 아틀라스입니다. 위 행은 가상 해운사 NORDLINE·AURORA CARGO·PELAGIC FREIGHT·SUNPORT LOGISTICS의 긴 면, 아래 행은 같은 색상의 후면 문·잠금봉·경첩입니다. 실존 해운사 이름·로고를 사용하지 않고 원본의 골·도색·마모·문 구조를 UV로 입힙니다. 원본은 이미지 생성 도구로 제작했고 외부 사진·브랜드 에셋을 입력하지 않았습니다. 원본은 `/workspace/generated_images/`에 보존합니다.

프로젝트 홍보6종과 상품 광고30종의 출처·프롬프트는 [프로젝트 홍보](project-promo-source.md)와 [상품 광고](product-ad-source.md)에 기록합니다. 경주 광고4종과 벡터8종을 포함한 전체48종 선택·순환은 [advertisement_library.gd](../../scripts/environment/advertisement_library.gd)가 담당합니다.

## 투어 도착지 5종 파노라마

image_gen.imagegen으로 생성한 2:1 위경도 이미지입니다. 외부 입력 이미지를 사용하지 않았습니다. 골 직전 도로 접선에 중심 경도를 맞추고 카메라의 실제 시선으로 다른 경도를 읽습니다. 카메라를 따라 도는 평면 카드가 아닙니다. 양 끝 경계는 좁은 영역에서 혼합합니다.

- `goal-canyon.png`: 생성 원본 `exec-38e4ef42-0170-4705-b6a5-3293f9d75bc5.png`. 360도 수평 시야·수평선·다른 방향의 실루엣·무문자·무차량·무도로를 요청했습니다.

- `goal-harbor.png`: 생성 원본 `exec-6f1e6596-eefc-439d-ab49-e388d6cd591d.png`. 360도 수평 시야·수평선·다른 방향의 실루엣·무문자·무차량·무도로를 요청했습니다.

- `goal-bamboo.png`: 생성 원본 `exec-be37aa7d-bdce-4efb-9349-b7de19695f4a.png`. 360도 수평 시야·수평선·다른 방향의 실루엣·무문자·무차량·무도로를 요청했습니다.

- `goal-snow.png`: 생성 원본 `exec-c08cfa25-6f24-4686-9e30-6cdaf2149975.png`. 360도 수평 시야·수평선·다른 방향의 실루엣·무문자·무차량·무도로를 요청했습니다.

- `goal-volcano.png`: 생성 원본 `exec-cb3cef87-2bf1-4748-a2bd-ab8d2e151de6.png`. 360도 수평 시야·수평선·다른 방향의 실루엣·무문자·무차량·무도로를 요청했습니다.

## 바다 표면

`ocean-ripples.png`는 image_gen.imagegen 원본 `exec-2a49ef68-4cf2-4483-8139-6dcf1da59c90.png`를 복사했습니다. 수직 정면·반복 가능한 청록 바다·작은 교차 물결·가느다란 포말·무문자·무해안·무선박을 요청했습니다. 실제 조명 아래 서로 다른 축척과 방향으로 두 번 이동 샘플링하고 파도 법선·프레넬·포말과 혼합합니다. 고정된 태양 반사를 이미지에 넣지 않도록 요청했습니다.

`tour-sand-variants.png`: image_gen.imagegen 원본 `exec-5798ecac-e2e0-46ac-8a0e-4fc3181ae218.png`. 같은 재료의 서로 다른 결4종을 2×2 정면·균일 조명·무문자·무소품·무발자국으로 요청했습니다. 원본을 재편집하지 않고 셰이더에서 셀을 혼합합니다.

`tour-snow-variants.png`: image_gen.imagegen 원본 `exec-d7305e91-c360-4e1f-9b13-49ff28c42772.png`. 같은 재료의 서로 다른 결4종을 2×2 정면·균일 조명·무문자·무소품·무발자국으로 요청했습니다. 원본을 재편집하지 않고 셰이더에서 셀을 혼합합니다.

`tour-grass-variants.png`: image_gen.imagegen 원본 `exec-b0b7479f-1cfb-483a-9b65-dbffa861315a.png`. 같은 재료의 서로 다른 결4종을 2×2 정면·균일 조명·무문자·무소품·무발자국으로 요청했습니다. 원본을 재편집하지 않고 셰이더에서 셀을 혼합합니다.

## 트랙2~5의360도 하늘·원경

image_gen.imagegen으로 제작한1774×887(2:1) 위경도 원본을 편집·확대하지 않고 복사했습니다. 각 원본에360도 수평 시야, 중앙 수평선, 방향마다 다른 풍경, 먼 지형, 자연스러운 구름, 무도로·무차량·무문자·실존 브랜드 제외를 요청했습니다. 외부 이미지를 입력하지 않았으며 원본은 `/workspace/generated_images/`에 보존합니다.

| 배포 이미지 | 생성 원본 | 방향별 원경 |
| --- | --- | --- |
| `speedway-panorama.png` | `exec-91bccf60-d2e8-434d-ac57-9b687bc399b6.png` | 바다·녹색 구릉·해안 도시·경기장 |
| `harbor-panorama.png` | `exec-2e298e2d-4ecd-44b9-85b5-fd480d8c613c.png` | 야간 도시·항만 크레인·화물선·해안 산맥 |
| `track-riviera-panorama.png` | `exec-49f9750e-df18-4376-9257-6d660938b467.png` | 청록 바다·섬·사암 능선·마을·녹색 산맥 |
| `gorge-sunset-panorama.png` | `exec-935341f2-e969-44b5-a8f4-90a4d96574ce.png` | 적색 메사·깊은 협곡·강 계곡·노을 |

[track_background.gd](../../scripts/environment/track_background.gd)와 [track_panorama.gdshader](../../shaders/track_panorama.gdshader)는 시선의 실제 경도·위도로 이미지를 읽습니다. 수평 양 끝의 좁은 영역만 혼합하며, 랩·카메라 방향에 따른 평면 회전이나 수평 늘이기를 하지 않습니다. 원경 하나만 현재 코스의 하늘이 소유하고 코스 해제 시 놓습니다. 원본은 손실 품질0.9·밉맵으로 임포트합니다. 태양·달의 이미지 내 위치에 맞춰 주광 방위·고도도 고정합니다. 기존 `riviera-sky-panorama.png`는 투어의 구름 전용 이미지로 계속 사용합니다.

## 경기장 벽 전용 가로 광고

`speedway-wall-ads.png`는 image_gen.imagegen 원본 `exec-5b61f14e-cc14-4118-bfa0-c4bf886adb98.png`를 그대로 복사한1774×887 이미지입니다. BRISK COLA·VELOX TIRES·SKYLINK MOBILE·CLOUDREST·PIXELBOX·SUNCOAST의 가상 광고6개를 낮고 긴 벽 부착 규격으로 요청했습니다. 각 행의 실제 높이 비율은 `speedway_environment.gd`의 `WALL_AD_EDGES`가 지정하며, 물리 높이1.18m와 원본 종횡비에 맞춰 폭을 정합니다. 이미지 자체를 잘라내거나 늘리지 않고 전용 UV로 인쇄면을 선택합니다. 실존 기업·회로·로고는 사용하지 않았으며 원본은 `/workspace/generated_images/`에 보존합니다. VRAM 압축·밉맵·이방성 필터링을 적용합니다.

대형 관중석의 형상·전용 관중 이미지 출처는 [모델 팩](../../models/props/stadium_grandstand/SOURCE.md)이 소유합니다. 경기장 잔디는 기존 생성형 지면 변형을 사용하고, 호수는 기존 `ocean-ripples.png`의 질감과 현재 하늘의 환경 반사를 사용합니다.

## 경기장 전용 외벽

`speedway-facades.png`는 image_gen.imagegen 생성 원본 `exec-5a334adc-862b-4fc4-9771-e4e6413e5462.png`를 편집 없이 복사했습니다. 동일한 크기의2×2 영역은 순서대로 피트 차고 출입면, 운영동 외벽, 관중석 통로 벽, 콘크리트 기초입니다. 가상 경기장의 미장·줄눈·금속 차고문·관람 창·환기구를 정면·균일 광원·무문자·무상표로 요청했습니다. 피트와 관중석은 이 전용 UV를 사용하며 원본은 `/workspace/generated_images/`에 보존합니다.

## 네온 전자상가

`neon-district-elevations.png`는 image_gen.imagegen 생성 원본 `exec-9cc48afb-eb02-4675-a670-5207756ba1b4.png`를 편집 없이 복사한 2열×2행 이미지입니다. 가상의 야간 전자상가·아케이드 STARCADE와 VOLTWORKS의 정면·측면을 같은 UV 규격으로 요청했습니다. [아케이드 건물](../../models/props/neon_arcade/SOURCE.md)과 [입체 간판](../../models/props/neon_pylon/SOURCE.md)의 GLB 메시가 이를 공유하고, 셰이더가 인스턴스별 업종과 발광을 선택합니다. 원본은 `/workspace/generated_images/`에 보존합니다.

## 정글 터널 암석

`jungle-moss-stone.png`는 image_gen.imagegen 생성 원본 `exec-d864443b-6e56-490b-9033-1cc81eec2d91.png`를 편집 없이 복사한 전용 이끼 암석 재질입니다. 습한 회색 암석·불규칙한 균열·미세한 덩굴 뿌리·짙은 이끼를 정면·균일광·무격자·무상표의 반복 표면으로 요청했습니다. 정글 터널 내벽·포털·흙덮개의 UV에 사용하며 원본은 `/workspace/generated_images/`에 보존합니다.

### 항만 화물 컨테이너

`harbor-cargo-surfaces.png`는2026-11-11 이미지 생성 도구로 제작한 TIDEMARK·NORTHWAKE·PORTLINE 가상 도색3종의 측면·쌍여닫이문·지붕 아틀라스입니다. 원본 생성 결과를 편집 없이 복사했고 소금 얼룩·녹·긁힘·잠금장치·강철 골이 포함됩니다. 모델과 야적장이 같은 이미지·면별 UV를 공유합니다. 실재 운송업체의 로고는 사용하지 않습니다.

## 동일 형상의 건물 외벽 스킨

2026-11-11 이미지 생성 도구로 기존 프로젝트 아틀라스를 참조해 제작했습니다. 원본을 편집·재단·확대하지 않고 복사했으며 외부 사진·실존 브랜드는 입력하지 않았습니다. 동일한4열×3행·문·창 위치·층수를 유지하면서 재료와 프레임을 바꿉니다.

| 배포 이미지 | 생성 원본 | 용도 |
| --- | --- | --- |
| `urban-facades-limestone.png` | `exec-5be44341-7256-47c3-911d-4d686b8c2c22.png` | 석회암·녹색 유리·푸른 회벽·청동 프레임 등12종 도시 외벽 |
| `urban-facades-clinker.png` | `exec-57a21b69-bbb5-4a3a-bd2c-037a4b133ee6.png` | 적벽돌·청색 유리·검은 석재·민트 회벽 등12종 도시 외벽 |
| `building-front-alternate.png` | `exec-3e503897-f34f-4ddc-a9a5-e92d792e5b76.png` | 상점·편의점·서비스동·아파트 등12개 전면 영역의 대체 테마 |
| `building-side-alternate.png` | `exec-f5e1f975-c92f-4ec7-bef2-f567d995e88f.png` | 대체 전면과 같은 재료·띠·층수의12개 측면 영역 |

도시 이미지는 기존 도시 아틀라스의 격자만 참고하고12개 영역을 모두 도시 외벽으로 요청했습니다. 두 번째 이미지의 낮은 층·반사·석재 패널도 정면 투영이며 별도 지붕·하늘·지면·식생을 넣지 않았습니다. 일반 건물 전면은 기존 정면의 개구부를 유지한 채 HARBOR CAFE·DAY MART·BAY INN 등의 가상 점포와 재료를 바꿨습니다. 측면은 기존 측면의 UV 격자와 새 전면을 함께 입력해 서로 맞췄습니다.

[facade_variants.gd](../../scripts/environment/facade_variants.gd)가 도시3세트·일반 외벽2세트를 선택합니다. 정면과 측면은 한 개체의 같은 스킨 번호를 공유하며, 선택 때문에 메시·충돌체·실척·드로 배치를 복제하지 않습니다. 일반 상점의 녹색·적색 입체 처마는 대체 스킨에서 청색 도장으로 맞춥니다. 기존 식생·바위·광고에는 이 도장 변형을 적용하지 않습니다. 새 이미지도 VRAM 압축·밉맵을 사용합니다. 원본은 `/workspace/generated_images/`에 보존합니다.

## 홍콩풍 네온 외벽

`hong-kong-night-facades.png`는 image_gen으로 제작한4열×3행의 야간 외벽 아틀라스입니다. 낡은 타일·벽돌·회벽, 실외기·창살·세로 네온 간판, 따뜻한 창빛을 조합한12종의 가상 상가·주거 외벽입니다. 특정 게임의 이미지·실존 상표를 사용하지 않았습니다. 생성 결과를 크기 변경 없이 이 PNG에 보존했으며 작업 원본 파일명은 `exec-00c65074-94ab-4738-8cfc-5578ba1a5ae7.png`입니다. 투어 네온 건물과 `neon_tenement`·`neon_blade_sign`의 전용 UV·셰이더에서 사용합니다.
