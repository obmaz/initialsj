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
| [circuit_track.gd](../scripts/circuit_track.gd), [speedway_course.gd](../scripts/speedway_course.gd) | 닫힌 서킷과 트랙 2 뱅킹 |
| [rival_brain.gd](../scripts/rival_brain.gd), [car_contact.gd](../scripts/car_contact.gd) | CPU 간격·차선·속도 판단과 차체 겹침 |
| [road_features.gd](../scripts/road_features.gd), [road_surface_state.gd](../scripts/road_surface_state.gd), [air_state.gd](../scripts/air_state.gd) | 패드·물·경사로의 배치, 노면 효과와 점프 |
| [regional_props_3d.gd](../scripts/regional_props_3d.gd), [road_biome.gd](../scripts/road_biome.gd) | 지역별 입체 오브젝트·건축과 공간별 묶음 렌더링 |
| [screen_transition.gd](../scripts/screen_transition.gd), [tunnel_lights.gd](../scripts/tunnel_lights.gd) | 화면 전환, 가려진 렌더 준비, 터널 조명 예산 |
| [impact_effect.gd](../scripts/impact_effect.gd), [render_budget.gd](../scripts/render_budget.gd) | 재사용 충돌 이펙트와 자동 렌더 품질 |
| [web/coast-rush-shell.html](../web/coast-rush-shell.html) | 다운로드·회전·설치 안내와 브라우저 뒤로가기 |

차량은 도로의 거리·차선 오프셋으로 이동하는 아케이드 주행 모델입니다. 노면과 차체는 실제 3D이지만 `VehicleBody3D` 타이어 시뮬레이션은 사용하지 않습니다. 내부 속도 단위는 m/s이며 HUD에서 km/h로 변환합니다. 레이스·카운트다운의 엔진 시간 배율은 1.2이고 메뉴·정지·장면 종료에서는 1로 복원합니다.

## 자동 검사

```sh
python3 tools/verify_repository.py
./tools/godot --headless --path . --script res://tests/race_test.gd
node tests/install_bridge_review.cjs
node tests/back_bridge_review.cjs
```

[저장소 검사기](../tools/verify_repository.py)는 실행 진입점에서의 리소스 도달성, 끊긴 참조, 짝이 없는 `.uid`/`.import`, 문서 링크와 `docs/`의 생성 산출물을 확인합니다. [race_test.gd](../tests/race_test.gd)는 투어·서킷·차량·니트로·충돌·CPU·노면·점프·드리프트·RPM·그래픽 품질·뒤로가기·3D 배치·터널·뱅킹 구조 회귀 검사를 실행합니다. Node 검사는 실제 HTML 셸의 설치·history 브리지를 DOM/history 모형으로 검사합니다.

검사 JSON과 캡처는 [report.gd](../tests/report.gd)를 통해 **`build/reports/`**에 생성하며 커밋하지 않습니다. 수치와 캡처가 필요하면 해당 검사로 다시 생성합니다. `tests/`의 독립 주행·오디오·시각 검사는 각 범위 확인용이며, 그래픽 검사는 실제 디스플레이가 필요합니다. 네이티브 렌더 제출 수나 브라우저 모의 검사를 휴대폰 프레임률로 해석하지 않습니다. 실제 안드로이드 뒤로가기·오디오·터널 프레임 간격은 실기기에서 추가로 확인합니다.

선택적인 `loading_review.cjs`, `orientation_button_review.cjs`, `touch_review.cjs`, `web_audio_review.cjs`는 Playwright와 Chromium, 실행 중인 Web export 서버가 필요합니다. `INITIALSJ_REVIEW_URL`로 서버 주소, `CHROMIUM_BIN`으로 Chromium 경로를 지정하며 기본 자동 검사에는 포함하지 않습니다.

## 웹 내보내기와 배포

```sh
mkdir -p build/site
./tools/godot --headless --path . --export-release Web build/site/index.html
cp web/retire-flutter-worker.js build/site/flutter_service_worker.js
touch build/site/.nojekyll
```

[export_presets.cfg](../export_presets.cfg)는 단일 스레드 웹 빌드와 가로 모드 PWA를 설정합니다. `build/site/`는 생성 결과이며 Git에서 제외합니다. 과거 루트 워커 주소의 호환용 정리 파일은 기존 브라우저 캐시를 해제하는 용도이므로 유지합니다.

[`main` 푸시](../.github/workflows/deploy-pages.yml)는 고정 엔진 확인, 가져오기, 저장소·주행·Node 검사, 웹 내보내기를 거쳐 [GitHub Pages](https://obmaz.github.io/initialsj/)에 배포합니다. 별도 [검사 workflow](../.github/workflows/godot-checks.yml)도 push와 PR에서 실행합니다. 배포 후 공개 HTML·WASM·PCK를 확인하고, 아트·셸 변경은 실제 출력물에서도 점검합니다.

저작권·출처 문서는 에셋과 함께 보존합니다. 음원은 [출처·라이선스](../assets/audio/LICENSE.txt)를 확인합니다. 게임 규칙은 [GAMEPLAY.md](GAMEPLAY.md), 이번 정리의 검토 범위는 [CODE_REVIEW.md](CODE_REVIEW.md)에 있습니다. 터널 내 비밀길과 공사 장벽을 부수는 경로는 현재 구현 범위에 포함되지 않습니다.
