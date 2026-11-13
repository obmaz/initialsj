# 개발·검사·배포

코드의 책임과 데이터 흐름은 [아키텍처](ARCHITECTURE.md), 시각 모델 제작은 [모델 제작](MODEL_PIPELINE.md)을 기준으로 합니다. 이 문서는 현재 실행 절차만 관리합니다.

## 환경 구성

```sh
./tools/setup_env.sh
./tools/setup_env.sh --check
```

고정 엔진은 `.godot-version`의 **Godot 4.7.2 stable**입니다. 실행은 `./tools/godot`을 사용합니다. 직접 설치했다면 `INITIALSJ_GODOT_BIN`에 같은 버전 실행 파일을 지정합니다.

- `setup_env.sh`는 Linux x86_64에서 엔진 설치·버전 확인·프로젝트 가져오기를 담당합니다. `curl`, `unzip`, `sha512sum`이 필요합니다.
- 웹 템플릿은 `./tools/setup_env.sh --templates web`로 준비합니다. `android`·`all`도 지원합니다.
- Codex·Claude·CI의 환경 설정에는 이 스크립트를 호출하는 한 줄만 둡니다. 버전·다운로드·가져오기 절차를 도구별로 복제하지 않습니다.
- 설치 사용자와 실행 사용자가 다르면 `INITIALSJ_GODOT_BIN`과 해당 설치의 `XDG_DATA_HOME`을 지정합니다.
- 기본 검사에는 Python 3과 Node.js가 필요합니다. 음원 재합성은 별도로 numpy·ffmpeg, 로고 제작은 fontTools를 사용합니다.

코딩 규칙과 개발용 포맷터 설치는 [코딩 규칙](CODING_STYLE.md#포맷과-이름)을 따릅니다. 개발 도구 버전은 [requirements-dev.txt](../tools/requirements-dev.txt)에서 고정합니다.

## 기본 검사

푸시 전에 아래 공통 명령을 로컬에서 통과시킵니다. 엔진 설치는 `setup_env.sh`, 검사는 `check.py`가 담당하며 검사 명령은 설치·내보내기·배포를 시작하지 않습니다.

```sh
python3 tools/check.py
# 원인 분리용 단계별 검사. 전체 검사를 대체하지 않습니다.
python3 tools/check.py --static
python3 tools/check.py --engine
```

`--static`은 포맷·Python 도구·원본 GLB·생성물·충돌 캐시·참조·문서 링크를 검사합니다. `--engine`은 엔진 버전·임포트·모델 계약·실제 게임 회귀·브라우저 브리지를 검사합니다. Godot가0으로 종료해도 `SCRIPT ERROR:`·`ERROR:`가 있으면 실패합니다. 단계별 제한 시간은15분이며 로그는 `build/reports/checks/`에 남습니다.

포맷터는 `INITIALSJ_GDFORMAT_BIN`, 로컬 가상환경, `PATH` 순서로 찾습니다. 로컬 실행 파일은 Windows의 `build/dev-venv/Scripts/gdformat.exe`, 그 외 환경의 `build/dev-venv/bin/gdformat`입니다. 설치 버전은 [코딩 규칙](CODING_STYLE.md#포맷과-이름)을 따릅니다. 렌더·입력 변경의 실제 브라우저 검사는 아래 [선택 검사](#선택-검사와-산출물)를 함께 수행합니다. CI를 새 코드의 첫 실행·진단 장소로 사용하지 않습니다.

저장소 검사기는 런타임 참조, 자동 등록 모델 팩, 누락·미사용 리소스, `.uid`·`.import` 누락·고아 파일, Markdown 상대 링크·제목 앵커, 사용하지 않는 셰이더 sampler와 음원 라이선스를 확인합니다. [편집 원본](../model_sources/README.md)의 누락·해시와 배포 GLB의 생성 상태도 확인합니다. 모델 목록은 정의 파일에서 자동 탐색하며 별도의 중앙 등록표가 없습니다.

코스별 정적 충돌 캐시의 입력·출력 해시도 검사합니다. 코스 형상·프로필·공통 생성 코드를 바꿨다면 [코스 팩의 충돌 자료 생성 절차](MODEL_PIPELINE.md#코스-팩)를 먼저 실행합니다. `check_world_collisions.py`는 이 항목만 빠르게 확인하는 독립 검사입니다.

텍스트의 체크아웃 줄바꿈은 [.gitattributes](../.gitattributes)의 LF 계약을 따릅니다. `.gd`·`.tres`·`.tscn`·`.json`의 실제 바이트가 충돌 입력 해시에 포함되므로 `core.autocrlf=true`에서도 LF를 유지합니다. GLB와 압축 충돌 `.res`는 바이너리로 보존합니다. 해시 검사기는 실제 바이트의 변경을 계속 감지합니다.

규칙 도입 전에 만들어진 Windows 작업 트리에는 CRLF 파일이 남아 있을 수 있습니다. 로컬 수정본을 보존한 채 편집기에서 해당 텍스트를 LF로 저장하거나 새로 체크아웃합니다. `git add --renormalize .`는 인덱스를 정규화하며 작업 트리의 기존 CRLF 바이트까지 다시 쓰지는 않습니다. 줄바꿈만 복구해 입력 해시가 일치하면 충돌 자료 재생성은 필요하지 않습니다.

`race_test.gd`는 실제 차체 주행·제동·후진·충돌·점프·분기·랩·롤링 스타트, 입력·화면 상태, 지역 배치, 붕괴·낙석, 모델 계약, 렌더·오디오 수명을 검사합니다. 실제 물리 검사는 `--fixed-fps 60`으로 실행합니다. 설계 여유 계산과 실제 물리 주행 검사는 구분합니다.

브라우저 브리지의 Node 검사는 실제 셸·오디오 코드를 모의 DOM/history/Web Audio에서 검사합니다. 실제 WebGL·터치·설치·오디오 출력은 웹 빌드에서 추가 확인합니다.

## 모델만 검사·미리보기

```sh
python3 tools/optimize_models.py --check
./tools/godot --headless --path . --script res://tools/check_models.gd
./tools/godot --headless --path . --script res://tools/check_models.gd -- --vehicle hatch
./tools/godot --path . --script res://tools/preview_model.gd -- --vehicle hatch
./tools/godot --path . --script res://tools/preview_model.gd -- --prop convenience_store --output build/reports/store.png
```

미리보기는 선택 모델과 1m 격자를 표시합니다. A/D는 회전, W/S는 거리 조정, Esc는 종료입니다. 이미지 저장에는 그래픽 세션이 필요하며 Linux CI에서는 Xvfb가 준비된 경우 `xvfb-run -a`를 앞에 붙입니다. 모델 계약·자료 형식·작업 범위는 [MODEL_PIPELINE.md](MODEL_PIPELINE.md)를 따릅니다.

## 선택 검사와 산출물

- `tests/circuit_drive_checks.gd`: 네 차량의 실제 3랩 주행. 오래 걸려 기본 CI에서는 제외합니다.
- `tests/loading_checks.cjs`, `orientation_button_checks.cjs`, `touch_checks.cjs`, `web_audio_checks.cjs`: Playwright·Chromium·실행 중인 Web export 서버가 필요합니다. `INITIALSJ_TEST_URL`과 `CHROMIUM_BIN`으로 대상을 지정합니다.
- `tools/bake_vehicle_audio.py --check`: 차량별 파일·레시피·클리핑·루프·음색 차이를 검사합니다. [음원 제작 기준](VEHICLE_AUDIO.md)을 따릅니다.

검사 JSON·캡처·미리보기는 `tests/report.gd`를 통해 `build/reports/`에 생성합니다. 일회성 리뷰, 측정 스크립트와 오래된 산출물은 소스에 보관하지 않습니다. 데스크톱 CPU 시간·SwiftShader 결과를 휴대폰 FPS로 해석하지 않습니다.

## 웹 내보내기

```sh
./tools/setup_env.sh --templates web
mkdir -p build/site
./tools/godot --headless --path . --export-release Web build/site/index.html
python3 tools/verify_web_export.py build/site/index.html
cp web/retire-flutter-worker.js build/site/flutter_service_worker.js
touch build/site/.nojekyll
```

Web 프리셋은 단일 스레드·가로 PWA이며 PC용 S3TC와 모바일용 ETC2를 함께 포함합니다. `build/site/`는 생성 결과입니다. `web/retire-flutter-worker.js`는 재방문 브라우저의 배포 캐시를 정리하는 호환 경로에 제공하므로 유지합니다.

## 푸시와 배포 확인

커밋 작성자·커미터는 `obmaz <zambobmaz@gmail.com>`을 사용합니다. 통합 전 원격 `main`을 받고 리베이스하며, 충돌은 파일 전체 덮어쓰기 대신 해당 모델·게임 규칙의 최종 의도에 맞춰 해결합니다.

자동 워크플로는 `godot-checks` 하나입니다. `main` 푸시와 `main` 대상 PR에서 로컬과 같은 `check.py`를 실행하며, 정적 `source-integrity` 작업이 성공해야 `check` 작업이 엔진 검사를 시작합니다. 두 상태 이름은 유지하고 GLB 검사를 중복 실행하지 않습니다. 같은 브랜치·PR의 오래된 실행은 취소하며 실패 로그만7일간 보관합니다. 긴 프레임 계측·후보 비교·시각 진단은 로컬에서 필요할 때 수행하고 자동 워크플로에 추가하지 않습니다.

대상 없는 “배포”는 Dropbox APK 전달이며, 웹은 명시 요청 시에만 `deploy-pages`를 workflow_dispatch로 실행합니다. 수동 웹 배포도 같은 공통 검사를 통과한 뒤 내보내기·게시합니다. 두 워크플로 모두 `setup_env.sh`로 환경을 준비합니다. main 푸시는 웹을 자동 게시하지 않습니다. 빌드와 게시 단계의 성공을 각각 확인하고 배포된 커밋·아티팩트를 대조합니다. 공개 URL 접근이 가능하면 앱 버전 또는 `index.pck`의 새 리소스 경로까지 확인합니다. 네트워크 제한 등으로 직접 접속하지 못한 경우 확인 범위를 보고합니다.

Android와 Dropbox 전달은 [ANDROID.md](ANDROID.md)와 [APK 스킬](../.agents/skills/dropbox-apk/SKILL.md)을 따릅니다. 일반 개발·검사·웹 배포에 APK 빌드를 추가하지 않습니다.

## 웹 오프라인·터치 확인

웹 내보내기는 [버전 플러그인](../addons/app_version/version_export.gd)이 [워커 정본](../web/offline_worker.js.in)과 [연결 코드](../web/offline_bridge.js)에서 실제 파일 목록·내용 해시가 같은 셸과 워커를 생성합니다. 첫 엔진 다운로드 전에 현재 워커의 제어를 확인해 WASM/PCK 요청을 한 번만 저장합니다. 설치 준비는 등록 완료가 아니라 본체 저장 완료를 확인하며 실패 응답은 캐시하지 않습니다. 공개 디렉터리 주소와 `index.html` 모두 오프라인 진입을 지원합니다. 저장소가 제한된 브라우저에서는 온라인 게임을 실행하고 설치 요청 시 오류를 안내합니다.

`python3 tools/verify_web_export.py build/site/index.html`은 기본 엔진 워커가 실수로 남거나 셸·워커 버전이 어긋난 산출물을 거부합니다. 수동 Pages 배포도 이 검사를 실행하며 자동 배포 범위는 바뀌지 않습니다.

실제 브라우저 터치 검사는 `INITIALSJ_TEST_URL=http://127.0.0.1:8787/ node tests/touch_checks.cjs`로 실행합니다. 하네스가 붙이는 `?diagnostics=1`에서만 [읽기 전용 진단](../scripts/platform/web_diagnostics.gd)을 연결합니다. 메뉴·선택·속도·페달·니트로·일시정지 상태를 관찰하며 상태 변경은 실제 터치로만 수행합니다. 일반 실행 URL에는 진단 API를 등록하지 않고 씬 종료 때 콜백을 해제합니다. 이 무거운 브라우저 검사는 선택 검사로 유지하며 push CI에 추가하지 않습니다.
