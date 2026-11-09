# 개발·검사·배포

## 실행 환경

사용 엔진은 [.godot-version](../.godot-version)에 고정한 **Godot 4.7.2 stable / GL Compatibility**입니다. [tools/godot](../tools/godot)은 버전이 다른 실행 파일을 거부합니다. 기본 설치 경로를 찾지 못하면 `INITIALSJ_GODOT_BIN`에 4.7.2 실행 파일 경로를 지정합니다. 웹 내보내기에는 같은 버전의 export templates가 필요합니다.

```sh
./tools/godot --path .
python3 tools/verify_repository.py
./tools/godot --headless --path . --script res://tests/verify_engine.gd
./tools/godot --headless --path . --editor --import --quit
```

### 처음 환경 만들기

새로 clone했거나 클라우드 컨테이너를 새로 만들었다면 [tools/setup_env.sh](../tools/setup_env.sh) 하나로 준비합니다. 환경 구성의 유일한 기준이며 특정 에이전트에 묶여 있지 않습니다. 사람, Codex, Claude, CI 모두 같은 스크립트를 부릅니다.

```sh
./tools/setup_env.sh                     # Godot 4.7.2 설치 + 프로젝트 가져오기(.godot 캐시)
./tools/setup_env.sh --templates web     # Web export 템플릿도 설치
./tools/setup_env.sh --check             # 아무것도 설치하지 않고 준비 상태만 확인
```

- 엔진은 `.godot-version`을 읽어 `~/.local/share/godot/engines/<버전>/`에 설치합니다. [tools/godot](../tools/godot)이 찾는 위치와 같습니다. 릴리스에 함께 올라오는 `SHA512-SUMS.txt`로 내려받은 파일을 검증하고, 이미 맞는 엔진이 있으면 건너뜁니다. 다시 실행해도 안전합니다. `--skip-import`를 주면 `.godot` 가져오기 캐시 생성도 건너뜁니다.
- `--templates web|android|all`은 export templates를 `${XDG_DATA_HOME:-~/.local/share}/godot/export_templates/<버전>.stable/`에 넣습니다. 템플릿 묶음은 약 1.3GB라서 기본 설치에서는 뺐습니다. 검사와 실행만 한다면 필요 없습니다. Android APK는 `tools/build_android.sh`가 템플릿과 SDK를 직접 설치하므로([ANDROID.md](ANDROID.md)) 컨테이너 캐시에 미리 넣어 두고 싶을 때만 `android`를 씁니다.
- 자동 설치는 Linux x86_64만 지원합니다. 다른 환경은 4.7.2 stable을 직접 설치하고 `INITIALSJ_GODOT_BIN`을 지정합니다. 이 변수가 가리키는 파일이 4.7.2 stable이 아니면 조용히 다른 엔진을 깔지 않고 실패합니다.
- 시스템 도구는 `curl`, `unzip`, `sha512sum`이 필요하고, 검사에는 `python3`와 `node`가 필요합니다. 없으면 어떤 도구가 없는지 알려 줍니다. 패키지는 스크립트가 설치하지 않습니다(권한이 필요한 작업이라서).

**에이전트·CI 환경 설정에는 이 스크립트를 부르는 한 줄만 넣습니다.** 엔진 버전이나 설치 단계를 에이전트별 설정에 복사하면 `.godot-version`과 어긋납니다. 스크립트는 자기 위치에서 저장소 루트를 찾으므로 어느 디렉터리에서 불러도 됩니다.

| 환경 | 넣을 곳 | 내용 |
| --- | --- | --- |
| Codex 클라우드 환경 | 환경의 setup script (컨테이너를 캐시한다면 maintenance script에도) | `./tools/setup_env.sh` (저장소 루트에서 실행될 때) |
| Claude 클라우드 환경 | 환경의 setup script. 체크아웃들이 있는 상위 디렉터리에서 시작합니다. | `if [ -d initialsj ]; then ./initialsj/tools/setup_env.sh; fi` |
| 로컬·CI | 직접 실행 | `./tools/setup_env.sh` (CI는 지금 `setup-godot` 액션을 씁니다) |

- 네트워크가 제한된 환경이라면 `github.com`과 `release-assets.githubusercontent.com`을 허용해야 합니다. 에이전트가 일하는 단계에서 인터넷이 꺼져 있을 수 있으므로 설치는 setup 단계에서 끝냅니다. Web export가 필요한 환경이라면 `--templates web`을 붙입니다.
- 엔진은 `$HOME` 기준으로 설치됩니다. setup 단계와 에이전트가 서로 다른 사용자로 실행되면 에이전트 쪽에서 `INITIALSJ_GODOT_BIN`으로 설치된 경로를 지정합니다.
- 서명 키 같은 비밀값은 저장소나 이 스크립트에 넣지 않고 각 환경의 secret 기능으로 관리합니다([ANDROID.md](ANDROID.md)).

## 소스 구조

| 위치 | 책임 |
| --- | --- |
| [race.gd](../scripts/race.gd), [hud.gd](../scripts/hud.gd) | 화면 상태, 입력, 주행 진행, 카메라와 HUD |
| [track.gd](../scripts/track.gd), [road_section.gd](../scripts/road_section.gd), [route_library.gd](../scripts/route_library.gd) | 투어 분기, 도로 좌표·폭·지형·테마 |
| [circuit_track.gd](../scripts/circuit_track.gd), [fuji_course.gd](../scripts/fuji_course.gd), [speedway_course.gd](../scripts/speedway_course.gd), [night_course.gd](../scripts/night_course.gd), [riviera_course.gd](../scripts/riviera_course.gd), [gorge_course.gd](../scripts/gorge_course.gd) | 다섯 서킷의 형상·고저차·뱅킹 |
| [world_race.gd](../scripts/world_race.gd), [world_car.gd](../scripts/world_car.gd), [fuji_collision.gd](../scripts/fuji_collision.gd) | 다섯 서킷(FUJI·SUNCOAST·MIDNIGHT·RIVIERA·GORGE)의 월드 차량 이동과 실제 노면·장벽 충돌체 |
| [circuit_progress.gd](../scripts/circuit_progress.gd) | 서킷 위치 계측과 순차 게이트·랩 판정 |
| [rival_brain.gd](../scripts/rival_brain.gd), [car_contact.gd](../scripts/car_contact.gd) | CPU 간격·차선·속도 판단과 차체 겹침 |
| [road_features.gd](../scripts/road_features.gd), [road_surface_state.gd](../scripts/road_surface_state.gd), [air_state.gd](../scripts/air_state.gd) | 패드·물·진흙·트럭·점프대·급하강의 배치, 노면 효과와 점프 |
| [regional_props_3d.gd](../scripts/regional_props_3d.gd), [road_biome.gd](../scripts/road_biome.gd) | 지역별 입체 오브젝트·건축과 공간별 묶음 렌더링 |
| [screen_transition.gd](../scripts/screen_transition.gd), [tunnel_lights.gd](../scripts/tunnel_lights.gd) | 화면 전환, 가려진 렌더 준비, 터널 조명 예산 |
| [impact_effect.gd](../scripts/impact_effect.gd), [render_budget.gd](../scripts/render_budget.gd) | 재사용 충돌·레일 불꽃 이펙트와 자동 렌더 품질(콘솔 절약 모드 포함) |
| [crash_state.gd](../scripts/crash_state.gd), [nitro_system.gd](../scripts/nitro_system.gd) | 가드레일 충돌 날아가기·구르기, 차량별 니트로 자원 |
| [gamepad_input.gd](../scripts/gamepad_input.gd), [haptics.gd](../scripts/haptics.gd) | 패드 상태 추적·버튼 이름, 패드 진동과 폰 진동 |
| [loading_card.gd](../scripts/loading_card.gd) | 코스를 다시 만들 때의 로딩 카드 |
| [vehicle_audio.gd](../scripts/vehicle_audio.gd), [racing_audio.gd](../scripts/racing_audio.gd), [file_audio.js](../web/file_audio.js) | 차량별 엔진·부스터·점화음·드리프트 소리의 매핑과 재생. 규칙은 [VEHICLE_AUDIO.md](VEHICLE_AUDIO.md) |
| [web/coast-rush-shell.html](../web/coast-rush-shell.html) | 다운로드·회전·설치 안내와 브라우저 뒤로가기 |

다섯 서킷은 `CharacterBody3D`의 실제 월드 위치·속도·차체 방향을 사용하며, `ConcavePolygonShape3D` 노면·장벽 충돌체와 접촉합니다. 도로 곡선 투영은 경기 정보용이고 일반 주행에서 차체를 곡선으로 이동시키지 않습니다. 고가 교차점의 위·아래 도로는 실제로 분리되어 있습니다. `circuit_progress.gd`는 높이와 순서가 있는 12개 게이트를 확인해 랩을 집계합니다.

투어만 거리·차선 오프셋으로 이동하는 아케이드(도로 좌표) 컨트롤러를 씁니다(구간을 즉석에서 만들고 갈라지는 구조라서). 두 컨트롤러가 함께 쓰는 벽 충돌·진동·점프 수치는 [drive_tuning.gd](../scripts/drive_tuning.gd)에 모아 둡니다. 두 방식 모두 `VehicleBody3D` 타이어 시뮬레이션은 사용하지 않습니다. 내부 속도 단위는 m/s이며 HUD에서 km/h로 변환합니다. 레이스·카운트다운의 엔진 시간 배율은 1.2이고 메뉴·정지·장면 종료에서는 1로 복원합니다.

[corner_resistance.gd](../scripts/corner_resistance.gd)는 횡가속도·접지력·실제 미끄러짐으로 타이어 저항을 계산합니다. 월드 차량은 실제 회전율과 속도를, 도로 좌표 주행은 곡률과 속도를 사용합니다. 최고속도 근처의 코너에서는 엔진 여유 힘을 줄여 저항이 매 프레임 즉시 상쇄되지 않게 하며, 직선 가속과 기본 제동은 유지합니다.

## 자동 검사

```sh
python3 tools/verify_repository.py
./tools/godot --headless --fixed-fps 60 --path . --script res://tests/race_test.gd
node tests/install_bridge_review.cjs
node tests/back_bridge_review.cjs
node tests/fullscreen_bridge_review.cjs
node tests/audio_lifecycle_review.cjs
```

[vehicle_audio_checks.gd](../tests/vehicle_audio_checks.gd)는 모든 차량이 자기 엔진·부스터·점화음·드리프트 파일을 갖는지, 다른 차량 파일을 재사용하지 않는지, 웹 루프가 파일과 일치하는지, 선택한 차량의 소리로 실제 플레이어가 바뀌는지 확인합니다. 소리를 만들거나 바꿀 때는 ffmpeg와 numpy가 필요한 `python3 tools/bake_vehicle_audio.py --check`로 클리핑·차량 간 음색 차이까지 확인하며, 이는 CI에 포함하지 않습니다([VEHICLE_AUDIO.md](VEHICLE_AUDIO.md)).

[저장소 검사기](../tools/verify_repository.py)는 실행 진입점에서의 리소스 도달성, 끊긴 참조, 짝이 없는 `.uid`/`.import`, 문서 링크와 `docs/`의 생성 산출물을 확인합니다. [race_test.gd](../tests/race_test.gd)는 투어·서킷·차량·니트로·충돌·CPU·노면·점프·드리프트·RPM·그래픽 품질·뒤로가기·3D 배치·터널·뱅킹 구조 회귀 검사를 실행합니다. Node 검사는 실제 HTML 셸의 설치·history 브리지를 DOM/history 모형으로 검사합니다.

[fuji_geometry_checks.gd](../tests/fuji_geometry_checks.gd)는 실제 물리 공간의 광선으로 노면·교량·터널 충돌체를 검사합니다. [world_car_checks.gd](../tests/world_car_checks.gd)와 [fuji_world_checks.gd](../tests/fuji_world_checks.gd)는 실제 물리 프레임을 진행하며 조향·접지·입체 교차·정지·후진과 컨트롤러 분리를 확인합니다. 여러 차량을 연속 실행하는 검사는 `--fixed-fps 60`으로 시간 진행을 고정합니다. 수학적인 위치 샘플링만으로 물리 주행을 검증하지 않습니다.

[world_rival_checks.gd](../tests/world_rival_checks.gd)는 정차 차량 추월·빈 차선 판단·후방 공간을 확인한 후진 복구를 실제 차체 간격과 함께 검사합니다. [circuit_drive_review.gd](../tests/circuit_drive_review.gd)는 모든 차량을 직접 조향·제동해 각각 3랩을 달립니다. 오래 걸리므로 CI에는 넣지 않았고, 명령 뒤 `-- 0`~`-- 3`을 붙이면 차량별로 나누어 실행할 수 있습니다.

검사 JSON과 캡처는 [report.gd](../tests/report.gd)를 통해 **`build/reports/`**에 생성하며 커밋하지 않습니다. 수치와 캡처가 필요하면 해당 검사로 다시 생성합니다. `race_test.gd`에 묶이지 않은 검사는 위의 긴 주행 검사와 아래 브라우저 검사뿐입니다. 네이티브 렌더 제출 수나 브라우저 모의 검사를 휴대폰 프레임률로 해석하지 않습니다. 실제 안드로이드 뒤로가기·오디오·터널 프레임 간격은 실기기에서 추가로 확인합니다.

선택적인 `loading_review.cjs`, `orientation_button_review.cjs`, `touch_review.cjs`, `web_audio_review.cjs`는 Playwright와 Chromium, 실행 중인 Web export 서버가 필요합니다. `INITIALSJ_REVIEW_URL`로 서버 주소, `CHROMIUM_BIN`으로 Chromium 경로를 지정하며 기본 자동 검사에는 포함하지 않습니다.

로고를 변경할 때는 `python3 tools/bake_logo.py`로 SVG와 웹 셸의 인라인 사본을 함께 갱신합니다. 이 제작 도구만 fontTools를 요구하며, 커밋된 SVG를 사용하는 게임 실행·빌드에는 추가 Python 패키지가 필요하지 않습니다. 아트 출처는 [GENERATED_ART.md](../assets/ui/GENERATED_ART.md)를 참고하세요.

[resource_lifecycle_checks.gd](../tests/resource_lifecycle_checks.gd)는 전체 검사에서 코스 전환·재시작·차량 교체·충돌 반복 후 노드와 리소스 수가 누적되지 않는지, 장면 해제 후 노드 수와 뷰포트 상태가 복구되는지 확인합니다. `audio_lifecycle_review.cjs`는 실제 Web Audio 브리지 소스로 A→B→A 비동기 선택·지연 디코딩·종료를 재현하며 루프와 연결·이벤트·버퍼 해제를 검사합니다. 첫 방문에서 늘어나는 폰트·셰이더·지역 모델 캐시와 WASM 힙의 최대 확보 크기를 지속 누수로 단정하지 않습니다.

## 에셋 압축

큰 이미지 11장(`assets/ui/*.png`와 타일 질감을 뺀 `assets/environment/*.png`)은 가져오기 설정을 손실 WebP(`compress/mode=1`, `compress/lossy_quality=0.92`)로 두었습니다. 처음 14장 기준으로 가져온 크기가 약 22.1MB에서 5.7MB로 줄었고, 메뉴·차고 화면은 변경 전후 PSNR이 42dB 이상으로 눈에 띄는 차이가 없습니다. 원본 PNG는 그대로입니다. 새 큰 이미지를 넣을 때도 같은 설정을 씁니다. 이 방식은 내려받는 크기만 줄이고 그래픽 메모리 사용량은 그대로입니다(메모리는 VRAM 압축이나 해상도 축소가 필요합니다).

### GPU 압축(타일 질감)

도로·흙·잔디 타일 질감 3장(`asphalt`, `dirt-shoulder`, `lakeside-grass`)은 GPU 압축(`compress/mode=2`)으로 가져옵니다. 프로젝트 설정에서 PC용(S3TC)과 모바일용(ETC2) 형식을 모두 만들도록 켜 두었고(`textures/vram_compression/*`), 어떤 형식을 파일에 담을지는 내보내기 프리셋(`export_presets.cfg`의 `vram_texture_compression/for_desktop`·`for_mobile`)이 정합니다. 웹은 둘 다 담아 PC·모바일·콘솔 브라우저를 모두 지원하고, 나중에 Android 프리셋을 만들면 `for_mobile=true`, `for_desktop=false`로 두어 APK에는 모바일 형식만 담습니다. 게임 코드는 바뀌지 않습니다. 장당 그래픽 메모리는 약 5.6MB에서 0.7MB로 줄었고(세 장 합계 약 16.8MB에서 2.1MB), 내려받는 크기는 두 형식을 담기 때문에 약 2MB 늘었습니다. 메뉴 아트와 파노라마처럼 그라데이션이 많은 이미지는 밴딩 때문에 GPU 압축하지 않습니다.

소리는 루프가 OGG이고, 짧은 WAV(효과음·점화음)는 가져올 때 QOA로 압축합니다([VEHICLE_AUDIO.md](VEHICLE_AUDIO.md)).

## 회귀 검사 범위

| 범위 | 확인하는 동작 |
| --- | --- |
| 경기 진행·입력 | 시간 만료 전 체크포인트·종료, 포커스·회전·정지, 중복 화면 이동, 키보드·패드·터치 메뉴 이동 |
| 차량·니트로 | 서로 다른 능력, 세 자원 방식, 새 누름 감지, 취소·회복, 기록과 결과 화면 |
| 충돌·피드백 | 차체 겹침 해소, 레일 스침·날아가기 단계, 히트스톱, 진동·불꽃, 재시작 초기화 |
| CPU·노면·점프 | 앞차·차선 안전, 패드·물·진흙·트럭, 공중 통과 후 착지, 높은 점프대 |
| 투어·터널 | 짧은 분기 직선, 급하강·좁은 도로·도로 폭, 터치 선택·수동 우선, 제한된 조명 |
| 배경·서킷 | 실제 3D 모델과 도로 간격, 순차 게이트·랩, 높이별 교차·물리 접지, 뱅킹과 관중석 기초 |
| 웹·품질 | 설치 안내, Back·Forward history, 로딩 화면, 오디오 수명, 느린 프레임 대응 |

## 알려진 엔진 제약

Godot 4.7.2 웹 런타임의 Emscripten `GL.getNewId`는 GL 객체 ID를 계속 늘리고, 삭제한 자리는 `null`로 남깁니다. 코스를 여러 번 오가면 실제 GL 객체 수는 일정해도 이 등록 배열과 GC 후 JS 힙은 커집니다. 앱의 노드·음원 누수와 구분해야 하며, 앱 쪽 수정으로는 해결되지 않습니다. 메뉴처럼 2D가 화면을 덮는 상태에서는 메인 뷰포트의 3D 렌더를 멈춰 불필요한 그리기를 줄입니다.

Android 내보내기와 APK 빌드는 [ANDROID.md](ANDROID.md)에 정리했습니다. 아이콘은 `python3 tools/bake_android_icons.py`로 다시 만들 수 있습니다.

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

저작권·출처 문서는 에셋과 함께 보존합니다. 음원은 [출처·라이선스](../assets/audio/LICENSE.txt)를 확인하고, 모든 에셋의 출처와 라이선스는 [ASSET_LICENSES.md](ASSET_LICENSES.md)에 있습니다. 검사기는 라이선스 항목이 없는 음원 파일을 실패로 처리합니다. 게임 규칙은 [GAMEPLAY.md](GAMEPLAY.md)에 있습니다. 터널 내 비밀길과 공사 장벽을 부수는 경로는 현재 구현 범위에 포함되지 않습니다.

## 프레임 비용과 최적화

실제 기기에서 부드러움을 좌우하는 것은 물리 한 번(60Hz)의 CPU 시간입니다. 주행 중 한 프레임의 스크립트 비용을 데스크톱에서 재면 투어는 약 0.4ms, FUJI는 약 4.8ms(원래 8.1ms), SUNCOAST는 약 9.3ms(원래 11.2ms)입니다. 플레이어만 달리면 둘 다 약 1.3~1.5ms입니다. 월드 물리의 대부분은 CPU 차량 7대의 차체 충돌 검사(차 1대당 약 1ms)입니다.

- **CPU 차량 단계**([world_race.gd](../scripts/world_race.gd)): 플레이어와 45m 안은 매 프레임, 45~150m는 번갈아 2프레임마다(직전 속도로 미끄러지듯 이동), 150m 밖은 물리 없이 도로를 따라 이동시킵니다(`carry_rival`). 공중에 있거나 막 충돌한 차는 항상 전체 시뮬레이션을 합니다. 150m 안으로 들어오면 같은 위치·속도의 실제 차체로 돌아옵니다. CPU 차의 바닥 붙이기 검사는 2프레임에 한 번만 합니다. 다만 출발 직후나 SUNCOAST처럼 7대가 모두 가까이 붙어 달리면 절감이 작습니다(그 경우 약 17% 감소).
- **가드레일 충돌체**([fuji_collision.gd](../scripts/fuji_collision.gd)): 직선은 8m, 완만한 굽이는 4m, 급커브는 2m 상자로 만들어 삼각형 수를 줄이면서 곡선 가드레일과의 오차를 (L/2)²/(2R)로 억제합니다.
- **HUD**([hud.gd](../scripts/hud.gd)): 네온 광선 줄을 2겹(안티앨리어싱 없음)으로, 버튼 원 좌표와 미니맵 외곽선을 한 번만 계산하도록 바꿔 프레임당 2.3ms를 1.5ms로 줄였습니다.
- **측정**: `Time.get_ticks_usec()`로 `race.step()`·`place_cars()`·`update_camera()` 앞뒤를 재고, 렌더 통계는 `Performance.get_monitor(RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` 등을 xvfb에서 읽었습니다(드로 콜 약 300, 프레임당 삼각형 18~30만). 이 값은 데스크톱 기준이라 휴대폰에서는 설정의 `SHOW FPS`로 직접 확인합니다.


### TRACK04 해안 주행

`riviera_course.gd`는 위치·접선·높이가 이어지는 폐곡선과 완만한 뱅킹을 만듭니다. `riviera_environment.gd`는 실제 도로 높이에 연결한 모래·절벽·초지 메시와 바다, 기존 지역 소품의 야자수·상점을 배치합니다. 차선 폭과 반복은 해당 코스에서만 `roadside_geometry.gd`의 메시 및 `lane_dash.gdshader` 매개변수를 변경합니다.

`world_car.gd`의 `coast_profile`은 TRACK04·05 플레이어에만 켭니다. 차체의 실제 진행 방향과 입력으로 슬립각을 만들며 도로 중심선으로 차를 강제로 붙이지 않습니다. `coast_drift.gd`는 실제 속도·슬립·접지·깨끗한 노면을 받아 점수·하트·배수·연결 유예를 계산하고 HUD는 고정된 일곱 슬롯을 그립니다. 새 차량 오디오를 복제하지 않고 선택 차량의 기존 음원 경로를 사용합니다.

`tests/riviera_checks.gd`는 코스 연결·높이·폭·전용 환경·코스 선택·기존 코스 프로파일 보존과 직선·공중 보상 금지, S자 연결·충돌 중단·재시작 초기화를 검사합니다.


### 장대교·협곡 공유 구조

`scenic_landmarks.gd`는 투어와 TRACK05가 함께 사용하는 현수교 메시·층상 절벽·고정 광고판을 만듭니다. 주탑·케이블·행거·거더·광고 지지대는 종류별 MultiMesh로 묶으며, 주행 충돌체는 도로·가드레일을 그대로 사용합니다. 광고판은 카메라를 향해 돌지 않는 고정 평면입니다. `tools/bake_scenic_ads.py`가 번들 Roboto 글꼴의 윤곽선으로 독자적인 가상 광고 SVG를 만듭니다.

`gorge_course.gd`는 긴 다리 직선과 협곡 S자를 연결하고 `gorge_environment.gd`가 수면·노면 아래 지형·공유 구조물을 배치합니다. 투어는 기존 분기·시간·도로 고도를 유지하며 첫 해안 구간의 지형만 다리 아래에서 낮추고, 협곡 루트에는 터널 전후로 절벽과 광고를 배치합니다.

`tests/gorge_checks.gd`는 두 모드의 구조물, 광고판의 가드레일 밖 배치, 터널 회피, 360개 실제 물리 광선의 노면 높이, 실제 조향·가속·제동·드리프트로 한 바퀴 완주와 패드 진입을 검사합니다.

### 구조물 표면과 모델 비례

현수교의 주탑은 SurfaceTool로 테이퍼와 모서리를 만들고 케이블·행거는 원형 단면을 사용합니다. 보강재·접합판·기초·교량 바닥과 광고판의 패널·프레임·후면 지지대는 종류별 MultiMesh로 묶습니다. 광고판은 16×7m, 뒷판 두께 0.42m이며 앞면을 기둥이 가리지 않습니다. 동적 조명 수는 늘리지 않습니다. 실제 주행 노면·가드레일 충돌체는 유지합니다.

사암 텍스처는 `python3 tools/bake_sandstone.py`로 다시 생성합니다(numpy·Pillow 필요). `sandstone.gdshader`가 RGB 색상과 알파 높이를 삼면 투영하며 높이 미분으로 미세 표면 법선을 보정합니다. 절벽의 면 분할·침식 요철은 메시에서, 미세 입자와 풍화는 텍스처·재질에서 처리합니다. 야자수는 `scenery_3d_checks.gd`의 개체별 3,200삼각형 한도를 유지합니다.
