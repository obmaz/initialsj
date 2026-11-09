# Initial SJ — Coast Rush

**[게임 실행](https://obmaz.github.io/initialsj/)** · [게임 규칙](docs/GAMEPLAY.md) · [개발·검사·배포](docs/DEVELOPMENT.md) · [차량별 사운드](docs/VEHICLE_AUDIO.md) · [에셋 출처·라이선스](docs/ASSET_LICENSES.md) · [Android APK](docs/ANDROID.md)

Godot **4.7.2 / GL Compatibility**로 만드는 가로 화면용 3D 아케이드 레이싱 게임입니다. 프로젝트는 저장소 루트의 [project.godot](project.godot)에서 엽니다.

- **TOUR**: 15개 지역 테마와 16개 경로로 구성한 5구간 오픈 로드 타임어택입니다. 체크포인트 뒤 직선 안내 구간에서 다음 갈림길을 고릅니다.
- **TRACK**: 약 5.72km의 **FUJI LAKESIDE**, 약 4.57km의 **SUNCOAST SPEEDWAY**, 약 2.75km의 야간 서킷 **MIDNIGHT HARBOR**, 약 3.64km의 해안 드리프트 코스 **AZURE RIVIERA**, 약 3.24km의 장대교·협곡 코스 **SCARLET GORGE**에서 8대가 3바퀴를 달립니다.
- **투어·트랙의 3D 주행**(모든 모드 공통): 실제 차체 방향으로 조향하는 `CharacterBody3D`가 노면·장벽 충돌체 위를 달립니다. 투어도 실제 노면·분기·점프대를 주행하며 하트 드리프트 보상을 제공합니다. FUJI에는 약 60.8m 고저차, 약 12도 뱅킹과 실제 위아래로 교차하는 고가 구간이 있습니다.
- **TRACK04 / AZURE RIVIERA**: 넓은 4차선 해안 도로와 굽이·고개를 이어 달립니다. 차체와 진행 방향이 어긋나는 지속 슬라이드, 실제 접지 드리프트로 모으는 하트·최대 5배 콤보를 제공합니다. 짧은 S자 전환은 이어지고 충돌·노면 이탈 시 콤보가 끊어집니다.
- **투어의 새 풍경 / TRACK05**: PALM COAST의 바다 위 장대교와 RED CANYON의 높은 층상 절벽·가상 브랜드 광고판을 추가했습니다. TRACK05는 짧은 고개 다리와 협곡 S자를 연결하며 트랙4의 슬라이드·하트 보상도 지원합니다.
- **차량**: NIMORI H, VELTRIX S, IRONVALE V8, STRAUD 6R. 최고속도·가속도·부스트·핸들링과 니트로 자원 방식이 서로 다릅니다. 선택 화면과 주행은 같은 3D 모델을 사용합니다.
- **주행**: 브레이크, 드리프트, 슬립스트림, 부스터 패드, 물웅덩이·진흙, 점프대, 급하강, 정차 트럭과 속도에 따라 날아가는 충돌, 패드·폰 진동을 제공합니다. 길가 나무·건물·랜드마크는 실제 3D 모델이며, 하늘과 먼 능선은 생성형 이미지도 사용합니다.

## 조작

모바일에서는 화면의 조향·GAS·BRAKE·DRIFT·NITRO 버튼을 사용합니다. 머슬카는 별도 CELL 버튼도 있습니다. 안드로이드 뒤로가기는 주행 중 일시정지, 정지 중 재개, 선택·설정 화면에서는 이전 게임 화면으로 연결됩니다. 메인 메뉴에서는 사이트를 나갈 수 있습니다.

| 키 | 동작 |
| --- | --- |
| W / ↑ · S / ↓ | 가속 · 제동 |
| A, D / ←, → | 조향 |
| Space | 조향과 함께 드리프트 진입, 다시 눌러 해제 |
| Shift · E | 니트로 · 머슬카 오버드라이브 셀 |
| P / Esc | 주행·출발 대기 일시정지 또는 재개 |
| Enter | 선택 차량으로 출발, 결과에서 차량 선택 |
| R · G | 레이스 재시작 · 정지 화면에서 메인 메뉴 |

**게임패드**는 일반적인 레이싱 패드 배치입니다(Xbox 이름 기준, PlayStation 패드는 이름이 자동으로 바뀝니다). 패드를 쓰는 동안 화면의 각 버튼 옆에 해당 패드 버튼 이름이 표시되고, 메뉴마다 하단에 조작 안내가 나옵니다.

| 패드 | 동작 |
| --- | --- |
| RT · LT | 가속 · 브레이크(정지 후 후진) |
| 왼쪽 스틱 · 십자키 좌우 | 조향 |
| A | 니트로 |
| X | 드리프트 진입, 다시 눌러 해제 |
| B | 머슬카 오버드라이브 셀 |
| Y | 차량 복구(RESET CAR가 나왔을 때) |
| LB · RB | 투어 분기에서 왼쪽·오른쪽 경로 선택 |
| Start · Back(View) | 일시정지·재개 (정지 화면에서 Y는 재시작) |
| 메뉴 | 십자키·왼쪽 스틱으로 금색 선택 틀 이동(좌우 카드, 위 설정·뒤로, 아래 복귀) 후 A 확인 · 차고에서는 십자키·스틱·LB·RB로 차량 선택, A 출발 · 설정에서는 위아래로 줄 이동 · X 트랙·SUNCOAST·재시도, 코스 선택에서 Y MIDNIGHT, Y 설정, B 뒤로 |

브라우저는 패드의 버튼을 한 번 누른 뒤에야 패드를 인식합니다. 패드 연결이 끊기면 레이스를 멈춥니다. 브라우저 정책상 패드 입력은 전체화면 전환을 허용하지 않아, 설정의 전체화면은 마우스·터치로 누릅니다.

드리프트는 약 90km/h 이상에서 사용하며 재사용 대기시간이 없습니다. 모든 트랙은 정지한 뒤 BRAKE/S를 약 0.45초 누르면 후진할 수 있습니다. 세로 화면에서는 회전 안내를 표시하고 진행 중인 레이스를 멈춥니다. 설정에서 설치, 소리, 움직임 줄이기, AUTO/HIGH/FAST 그래픽 품질을 선택합니다.

## 실행과 검사

처음 clone했다면 `./tools/setup_env.sh`가 고정된 Godot 4.7.2를 내려받아 설치하고 프로젝트를 가져옵니다(사람·Codex·Claude·CI 공통, 다시 실행해도 안전). 이후 버전 고정 실행기를 사용합니다. 직접 설치했거나 경로가 다르면 `INITIALSJ_GODOT_BIN`에 실행 파일을 지정합니다. Web export 템플릿과 에이전트 환경 설정 방법은 [개발 문서](docs/DEVELOPMENT.md)를 참고하세요.

```sh
./tools/setup_env.sh
./tools/godot --path .
python3 tools/verify_repository.py
./tools/godot --headless --path . --editor --import --quit
./tools/godot --headless --fixed-fps 60 --path . --script res://tests/race_test.gd
node tests/install_bridge_review.cjs
node tests/back_bridge_review.cjs
node tests/fullscreen_bridge_review.cjs
node tests/audio_lifecycle_review.cjs
```

**Android APK**: 사용자 요청 시 로컬에서 빌드하고 연결된 Dropbox 플러그인으로 `/앱/initialsj`에 전달합니다. 절차는 [APK 전달 스킬](.agents/skills/dropbox-apk/SKILL.md), 설정과 서명은 [ANDROID.md](docs/ANDROID.md)를 따릅니다.

검사 보고서와 화면 캡처는 Git에서 제외하는 `build/reports/`에 생성합니다. `main` 푸시는 자동 검사 후 GitHub Pages의 `/initialsj/`에 배포됩니다. 자세한 내보내기 명령과 검사 범위는 [개발 문서](docs/DEVELOPMENT.md)를 참고하세요.

차량마다 엔진·부스터·드리프트 소리(OGG 루프)와 부스터 점화음(WAV)이 모두 다릅니다. 직접 합성한 원본이며 새 차량도 같은 규칙을 따릅니다([차량별 사운드](docs/VEHICLE_AUDIO.md)). 충돌·안내 소리는 WAV 파일입니다. [음원 출처와 라이선스](assets/audio/LICENSE.txt)는 에셋과 함께 유지하며, 전체 에셋의 출처와 라이선스는 [ASSET_LICENSES.md](docs/ASSET_LICENSES.md)에 정리했습니다. 변경 이력과 이전 구현은 Git 이력에서 확인할 수 있습니다.
