# Initial SJ — Coast Rush

**[게임 실행](https://obmaz.github.io/initialsj/)** · [게임 규칙](docs/GAMEPLAY.md) · [개발·검사·배포](docs/DEVELOPMENT.md) · [검토 범위](docs/CODE_REVIEW.md)

Godot **4.7.2 / GL Compatibility**로 만드는 가로 화면용 3D 아케이드 레이싱 게임입니다. 프로젝트는 저장소 루트의 [project.godot](project.godot)에서 엽니다.

- **TOUR**: 15개 지역 테마와 16개 경로로 구성한 5구간 오픈 로드 타임어택입니다. 체크포인트 뒤 직선 안내 구간에서 다음 갈림길을 고릅니다.
- **TRACK**: 약 5.72km의 **FUJI LAKESIDE**와 약 4.57km의 **SUNCOAST SPEEDWAY**에서 8대가 3바퀴를 달립니다.
- **트랙 1의 3D 주행**: 실제 차체 방향으로 조향하는 `CharacterBody3D`가 노면·장벽 충돌체 위를 달립니다. 약 60.8m 고저차, 약 12도 뱅킹과 실제 위아래로 교차하는 고가 구간이 있습니다.
- **차량**: NIMORI H, VELTRIX S, IRONVALE V8. 최고속도·가속도·부스트·핸들링과 니트로 자원 방식이 서로 다릅니다. 선택 화면과 주행은 같은 3D 모델을 사용합니다.
- **주행**: 브레이크, 드리프트, 슬립스트림, 부스터 패드, 물웅덩이, 점프대와 충돌 피드백을 제공합니다. 길가 나무·건물·랜드마크는 실제 3D 모델이며, 하늘과 먼 능선은 생성형 이미지도 사용합니다.

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

드리프트는 약 90km/h 이상에서 사용하며 재사용 대기시간이 없습니다. 트랙 1에서는 정지한 뒤 BRAKE/S를 약 0.45초 누르면 후진할 수 있습니다. 세로 화면에서는 회전 안내를 표시하고 진행 중인 레이스를 멈춥니다. 설정에서 설치, 소리, 움직임 줄이기, AUTO/HIGH/FAST 그래픽 품질을 선택합니다.

## 실행과 검사

Godot 4.7.2를 설치한 뒤 버전 고정 실행기를 사용합니다. 경로가 다르면 `INITIALSJ_GODOT_BIN`에 실행 파일을 지정합니다.

```sh
./tools/godot --path .
python3 tools/verify_repository.py
./tools/godot --headless --path . --editor --import --quit
./tools/godot --headless --fixed-fps 60 --path . --script res://tests/race_test.gd
node tests/install_bridge_review.cjs
node tests/back_bridge_review.cjs
node tests/fullscreen_bridge_review.cjs
```

검사 보고서와 화면 캡처는 Git에서 제외하는 `build/reports/`에 생성합니다. `main` 푸시는 자동 검사 후 GitHub Pages의 `/initialsj/`에 배포됩니다. 자세한 내보내기 명령과 검사 범위는 [개발 문서](docs/DEVELOPMENT.md)를 참고하세요.

엔진·타이어 소리는 OGG 녹음 루프, 충돌·안내 소리는 WAV 파일입니다. [음원 출처와 라이선스](assets/audio/LICENSE.txt)는 에셋과 함께 유지합니다. 변경 이력과 이전 구현은 Git 이력에서 확인할 수 있습니다.
