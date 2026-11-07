# 개발·검사·배포

## 실행 환경

사용 엔진은 [.godot-version](../.godot-version)에 고정한 **Godot 4.7.2 stable / GL Compatibility**입니다. [tools/godot](../tools/godot)은 버전이 다른 실행 파일을 거부합니다. 기본 설치 경로를 찾지 못하면 `INITIALSJ_GODOT_BIN`에 4.7.2 실행 파일 경로를 지정합니다. 웹 내보내기에는 같은 버전의 export templates가 필요합니다.

```sh
./tools/godot --path .
python3 tools/verify_repository.py
./tools/godot --headless --path . --script res://tests/verify_engine.gd
./tools/godot --headless --path . --editor --import --quit
```

## 소스 구조

| 위치 | 책임 |
| --- | --- |
| [race.gd](../scripts/race.gd), [hud.gd](../scripts/hud.gd) | 화면 상태, 입력, 주행 진행, 카메라와 HUD |
| [track.gd](../scripts/track.gd), [road_section.gd](../scripts/road_section.gd), [route_library.gd](../scripts/route_library.gd) | 투어 분기, 도로 좌표·폭·지형·테마 |
| [circuit_track.gd](../scripts/circuit_track.gd), [fuji_course.gd](../scripts/fuji_course.gd), [speedway_course.gd](../scripts/speedway_course.gd) | 두 서킷의 형상·고저차·뱅킹 |
| [world_race.gd](../scripts/world_race.gd), [world_car.gd](../scripts/world_car.gd), [fuji_collision.gd](../scripts/fuji_collision.gd) | 트랙 1의 월드 차량 이동과 실제 노면·장벽 충돌체 |
| [circuit_progress.gd](../scripts/circuit_progress.gd) | 트랙 1 위치 계측과 순차 게이트·랩 판정 |
| [rival_brain.gd](../scripts/rival_brain.gd), [car_contact.gd](../scripts/car_contact.gd) | CPU 간격·차선·속도 판단과 차체 겹침 |
| [road_features.gd](../scripts/road_features.gd), [road_surface_state.gd](../scripts/road_surface_state.gd), [air_state.gd](../scripts/air_state.gd) | 패드·물·경사로의 배치, 노면 효과와 점프 |
| [regional_props_3d.gd](../scripts/regional_props_3d.gd), [road_biome.gd](../scripts/road_biome.gd) | 지역별 입체 오브젝트·건축과 공간별 묶음 렌더링 |
| [screen_transition.gd](../scripts/screen_transition.gd), [tunnel_lights.gd](../scripts/tunnel_lights.gd) | 화면 전환, 가려진 렌더 준비, 터널 조명 예산 |
| [impact_effect.gd](../scripts/impact_effect.gd), [render_budget.gd](../scripts/render_budget.gd) | 재사용 충돌 이펙트와 자동 렌더 품질 |
| [vehicle_audio.gd](../scripts/vehicle_audio.gd), [racing_audio.gd](../scripts/racing_audio.gd), [file_audio.js](../web/file_audio.js) | 차량별 엔진·부스터·점화음·드리프트 소리의 매핑과 재생. 규칙은 [VEHICLE_AUDIO.md](VEHICLE_AUDIO.md) |
| [web/coast-rush-shell.html](../web/coast-rush-shell.html) | 다운로드·회전·설치 안내와 브라우저 뒤로가기 |

트랙 1은 `CharacterBody3D`의 실제 월드 위치·속도·차체 방향을 사용하며, `ConcavePolygonShape3D` 노면·장벽 충돌체와 접촉합니다. 도로 곡선 투영은 경기 정보용이고 일반 주행에서 차체를 곡선으로 이동시키지 않습니다. 고가 교차점의 위·아래 도로는 실제로 분리되어 있습니다. `circuit_progress.gd`는 높이와 순서가 있는 12개 게이트를 확인해 랩을 집계합니다.

투어와 SUNCOAST는 거리·차선 오프셋으로 이동하는 기존 아케이드 컨트롤러를 유지합니다. 두 방식 모두 `VehicleBody3D` 타이어 시뮬레이션은 사용하지 않습니다. 내부 속도 단위는 m/s이며 HUD에서 km/h로 변환합니다. 레이스·카운트다운의 엔진 시간 배율은 1.2이고 메뉴·정지·장면 종료에서는 1로 복원합니다.

[corner_resistance.gd](../scripts/corner_resistance.gd)는 횡가속도·접지력·실제 미끄러짐으로 타이어 저항을 계산합니다. 월드 차량은 실제 회전율과 속도를, 도로 좌표 주행은 곡률과 속도를 사용합니다. 최고속도 근처의 코너에서는 엔진 여유 힘을 줄여 저항이 매 프레임 즉시 상쇄되지 않게 하며, 직선 가속과 기본 제동은 유지합니다.

## 자동 검사

```sh
python3 tools/verify_repository.py
./tools/godot --headless --fixed-fps 60 --path . --script res://tests/race_test.gd
node tests/install_bridge_review.cjs
node tests/back_bridge_review.cjs
node tests/fullscreen_bridge_review.cjs
```

[vehicle_audio_checks.gd](../tests/vehicle_audio_checks.gd)는 모든 차량이 자기 엔진·부스터·점화음·드리프트 파일을 갖는지, 다른 차량 파일을 재사용하지 않는지, 웹 루프가 파일과 일치하는지, 선택한 차량의 소리로 실제 플레이어가 바뀌는지 확인합니다. 소리를 만들거나 바꿀 때는 ffmpeg와 numpy가 필요한 `python3 tools/bake_vehicle_audio.py --check`로 클리핑·차량 간 음색 차이까지 확인하며, 이는 CI에 포함하지 않습니다([VEHICLE_AUDIO.md](VEHICLE_AUDIO.md)).

[저장소 검사기](../tools/verify_repository.py)는 실행 진입점에서의 리소스 도달성, 끊긴 참조, 짝이 없는 `.uid`/`.import`, 문서 링크와 `docs/`의 생성 산출물을 확인합니다. [race_test.gd](../tests/race_test.gd)는 투어·서킷·차량·니트로·충돌·CPU·노면·점프·드리프트·RPM·그래픽 품질·뒤로가기·3D 배치·터널·뱅킹 구조 회귀 검사를 실행합니다. Node 검사는 실제 HTML 셸의 설치·history 브리지를 DOM/history 모형으로 검사합니다.

[fuji_geometry_checks.gd](../tests/fuji_geometry_checks.gd)는 실제 물리 공간의 광선으로 노면·교량·터널 충돌체를 검사합니다. [world_car_checks.gd](../tests/world_car_checks.gd)와 [fuji_world_checks.gd](../tests/fuji_world_checks.gd)는 실제 물리 프레임을 진행하며 조향·접지·입체 교차·정지·후진과 컨트롤러 분리를 확인합니다. 여러 차량을 연속 실행하는 검사는 `--fixed-fps 60`으로 시간 진행을 고정합니다. 수학적인 위치 샘플링만으로 물리 주행을 검증하지 않습니다.

[world_rival_checks.gd](../tests/world_rival_checks.gd)는 정차 차량 추월·빈 차선 판단·후방 공간을 확인한 후진 복구를 실제 차체 간격과 함께 검사합니다. [circuit_drive_review.gd](../tests/circuit_drive_review.gd)는 세 차량을 직접 조향·제동해 각각 3랩을 달립니다. 명령 뒤 `-- 0`, `-- 1`, `-- 2`를 붙이면 차량별로 나누어 실행할 수 있습니다.

검사 JSON과 캡처는 [report.gd](../tests/report.gd)를 통해 **`build/reports/`**에 생성하며 커밋하지 않습니다. 수치와 캡처가 필요하면 해당 검사로 다시 생성합니다. `tests/`의 독립 주행·오디오·시각 검사는 각 범위 확인용이며, 그래픽 검사는 실제 디스플레이가 필요합니다. 네이티브 렌더 제출 수나 브라우저 모의 검사를 휴대폰 프레임률로 해석하지 않습니다. 실제 안드로이드 뒤로가기·오디오·터널 프레임 간격은 실기기에서 추가로 확인합니다.

선택적인 `loading_review.cjs`, `orientation_button_review.cjs`, `touch_review.cjs`, `web_audio_review.cjs`는 Playwright와 Chromium, 실행 중인 Web export 서버가 필요합니다. `INITIALSJ_REVIEW_URL`로 서버 주소, `CHROMIUM_BIN`으로 Chromium 경로를 지정하며 기본 자동 검사에는 포함하지 않습니다.

로고를 변경할 때는 `python3 tools/bake_logo.py`로 SVG와 웹 셸의 인라인 사본을 함께 갱신합니다. 이 제작 도구만 fontTools를 요구하며, 커밋된 SVG를 사용하는 게임 실행·빌드에는 추가 Python 패키지가 필요하지 않습니다. 아트 출처는 [GENERATED_ART.md](../assets/ui/GENERATED_ART.md)를 참고하세요.

## 웹 내보내기와 배포

```sh
mkdir -p build/site
./tools/godot --headless --path . --export-release Web build/site/index.html
cp web/retire-flutter-worker.js build/site/flutter_service_worker.js
touch build/site/.nojekyll
```

[export_presets.cfg](../export_presets.cfg)는 단일 스레드 웹 빌드와 가로 모드 PWA를 설정합니다. `build/site/`는 생성 결과이며 Git에서 제외합니다. 과거 루트 워커 주소의 호환용 정리 파일은 기존 브라우저 캐시를 해제하는 용도이므로 유지합니다.

[`main` 푸시](../.github/workflows/deploy-pages.yml)는 고정 엔진 확인, 가져오기, 저장소·주행·Node 검사, 웹 내보내기를 거쳐 [GitHub Pages](https://obmaz.github.io/initialsj/)에 배포합니다. 별도 [검사 workflow](../.github/workflows/godot-checks.yml)도 push와 PR에서 실행합니다. 배포 후 공개 HTML·WASM·PCK를 확인하고, 아트·셸 변경은 실제 출력물에서도 점검합니다.

워크플로가 성공했는지보다 **공개 사이트가 실제로 바뀌었는지**를 확인합니다. 공개 `index.pck`를 내려받아 이번 변경에만 있는 경로(예: 새 에셋 이름)가 들어 있는지 보거나, `curl -I https://obmaz.github.io/initialsj/index.pck`의 `content-length`가 이전 값에서 바뀌었는지 봅니다. 빌드가 성공해도 마지막 `Deploy to GitHub Pages` 단계가 실패하면 사이트는 이전 버전 그대로입니다.

`deploy-pages`는 커밋 해시를 배포 ID로 씁니다. 2026-11-07에 이 단계가 `syncing_files`에서 10분 제한까지 끝나지 않아 취소된 뒤, 같은 커밋으로 실패한 job을 다시 실행하거나 워크플로를 새로 실행한 두 번은 배포 상태가 끝까지 비어 있는 채 같은 제한에서 실패했습니다. 이럴 때는 같은 커밋을 반복해서 돌리지 말고 새 커밋을 `main`에 푸시해 새 배포 ID로 시도합니다. GitHub 상태 페이지가 정상이어도 일어날 수 있습니다.

저작권·출처 문서는 에셋과 함께 보존합니다. 음원은 [출처·라이선스](../assets/audio/LICENSE.txt)를 확인합니다. 게임 규칙은 [GAMEPLAY.md](GAMEPLAY.md), 이번 정리의 검토 범위는 [CODE_REVIEW.md](CODE_REVIEW.md)에 있습니다. 터널 내 비밀길과 공사 장벽을 부수는 경로는 현재 구현 범위에 포함되지 않습니다.
