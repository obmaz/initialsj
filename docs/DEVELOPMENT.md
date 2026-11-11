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

```sh
build/dev-venv/bin/gdformat --check scripts models addons tests tools
python3 -m unittest discover -s tools -p 'test_*.py'
python3 tools/verify_repository.py
./tools/godot --headless --path . --editor --import --quit
./tools/godot --headless --fixed-fps 60 --path . --script res://tests/race_test.gd
node tests/install_bridge_checks.cjs
node tests/back_bridge_checks.cjs
node tests/fullscreen_bridge_checks.cjs
node tests/audio_lifecycle_checks.cjs
```

저장소 검사기는 런타임 참조, 자동 등록 모델 팩, 누락·미사용 리소스, `.uid`·`.import` 누락·고아 파일, Markdown 상대 링크·제목 앵커, 사용하지 않는 셰이더 sampler와 음원 라이선스를 확인합니다. [편집 원본](../model_sources/README.md)의 누락·해시와 배포 GLB의 생성 상태도 확인합니다. 모델 목록은 정의 파일에서 자동 탐색하며 별도의 중앙 등록표가 없습니다.

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
cp web/retire-flutter-worker.js build/site/flutter_service_worker.js
touch build/site/.nojekyll
```

Web 프리셋은 단일 스레드·가로 PWA이며 PC용 S3TC와 모바일용 ETC2를 함께 포함합니다. `build/site/`는 생성 결과입니다. `web/retire-flutter-worker.js`는 재방문 브라우저의 배포 캐시를 정리하는 호환 경로에 제공하므로 유지합니다.

## 푸시와 배포 확인

커밋 작성자·커미터는 `obmaz <zambobmaz@gmail.com>`을 사용합니다. 통합 전 원격 `main`을 받고 리베이스하며, 충돌은 파일 전체 덮어쓰기 대신 해당 모델·게임 규칙의 최종 의도에 맞춰 해결합니다.

`main` 푸시의 `godot-checks`는 기본 검사만 수행합니다. 대상 없는 “배포”는 Dropbox APK 전달이며, 웹은 명시 요청 시에만 `deploy-pages`를 workflow_dispatch로 실행합니다. main 푸시는 웹을 자동 게시하지 않습니다. 빌드와 게시 단계의 성공을 각각 확인하고 배포된 커밋·아티팩트를 대조합니다. 공개 URL 접근이 가능하면 앱 버전 또는 `index.pck`의 새 리소스 경로까지 확인합니다. 네트워크 제한 등으로 직접 접속하지 못한 경우 확인 범위를 보고합니다.

Android와 Dropbox 전달은 [ANDROID.md](ANDROID.md)와 [APK 스킬](../.agents/skills/dropbox-apk/SKILL.md)을 따릅니다. 일반 개발·검사·웹 배포에 APK 빌드를 추가하지 않습니다.
