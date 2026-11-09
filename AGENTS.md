# AI 개발 지침

이 파일은 저장소 전체에 적용됩니다.

- 모든 커밋의 작성자와 커미터는 `obmaz <zambobmaz@gmail.com>`을 사용합니다. API로 커밋할 때도 이 정보를 명시합니다. 로컬 Git 설정은 GitHub API의 작성자 정보에 적용되지 않습니다.
- 저장소는 `obmaz/initialsj`, GitHub Pages 주소는 `https://obmaz.github.io/initialsj/`입니다.
- Godot 프로젝트는 저장소 루트에 있습니다. 현재 모드는 TOUR, Fuji TRACK01, SUNCOAST SPEEDWAY TRACK02, MIDNIGHT HARBOR TRACK03(야간), AZURE RIVIERA TRACK04(해안 드리프트), SCARLET GORGE TRACK05(장대교·협곡)입니다.
- 제품명과 표지판은 가상 이름을 사용합니다. 스피드웨이의 실제 모티브를 게임 내 문구에 넣지 않습니다.
- Godot **4.7.2**를 `./tools/godot`으로 실행합니다. `.godot-version`과 `tests/verify_engine.gd`가 엔진 버전을 검사합니다.
- 새 환경은 `./tools/setup_env.sh`로 만듭니다(`--check`는 준비 상태 확인, `--templates web|android|all`은 export templates 추가). 이 스크립트가 특정 에이전트에 묶이지 않은 유일한 환경 구성 기준입니다. Codex·Claude·CI의 환경 설정에는 이 스크립트를 부르는 한 줄만 두고 단계를 복사하지 않습니다. 설치 로직을 바꾸면 스크립트에서 바꾸고 `docs/DEVELOPMENT.md`의 "처음 환경 만들기"도 함께 갱신합니다.
- 차량마다 엔진·부스터·부스터 시작·드리프트 음원을 독립적으로 소유하며 다른 차량의 파일을 공유하거나 복사하지 않습니다. 차량 추가·이름 변경·조정 시 `docs/VEHICLE_AUDIO.md`를 따릅니다(`catalog`의 `audio` 블록, `tools/bake_vehicle_audio.py` 생성법, 임포트 보조 파일, 출처, 문서). `tests/vehicle_audio_checks.gd`가 이 규칙을 검사합니다.
- 현재 동작 문서는 README와 `docs/`에 둡니다. 생성 보고서·측정값·스크린샷은 Git에서 제외한 `build/reports/`에 두며 일회성 검토 산출물을 커밋하지 않습니다.
- 대체된 소스와 리소스는 실행 코드·테스트의 참조를 확인한 뒤 `.uid`·`.import` 보조 파일과 함께 제거합니다. 글꼴·음원 라이선스와 에셋 출처를 최신 상태로 유지합니다.
- `web/retire-flutter-worker.js`를 보존합니다. 배포 시 과거 워커 URL에서 이 파일을 제공하여 재방문 브라우저가 예전 Flutter 배포 캐시를 해제하도록 합니다.
- 사용자는 반복적인 검토·수정, 필요한 이미지 생성, 푸시와 Pages 배포를 승인했습니다. 검증된 기능 변경은 배포까지 진행합니다.
- 지침과 스킬은 한국어로 작성합니다. 명령어·경로·API 식별자는 원래 표기를 유지합니다.

## 도구별 지침과 스킬 위치

- 공통 규칙의 정본은 `AGENTS.md`입니다. Claude Code는 같은 폴더의 `CLAUDE.md`에서 `@AGENTS.md`로 가져오며 Gemini CLI는 `GEMINI.md`에서 같은 정본을 가져옵니다. 공통 규칙은 정본에만 작성합니다.
- APK 전달 절차의 정본은 `.agents/skills/dropbox-apk/SKILL.md`입니다. `.claude/skills/dropbox-apk/SKILL.md`는 같은 정본을 읽도록 안내하는 포인터이며 절차를 복제하지 않습니다.
- `.agents/skills/dropbox-apk/agents/openai.yaml`은 스킬의 표시 이름·설명·기본 요청을 정의합니다. 실제 빌드·전달 절차는 `SKILL.md`를 따릅니다.

## APK 빌드와 Dropbox 전달

- Android 디버그 서명은 `obmaz/commuzip`의 키와 동일한 `tools/android-test.keystore`를 사용합니다. 별칭은 `androiddebugkey`, 비밀번호는 `android`이며 키를 환경마다 재생성하지 않습니다. 자세한 지문과 전환 시 주의사항은 `docs/ANDROID.md`를 따릅니다.

- 빌드 전에 Dropbox의 `/앱/initialsj/latest-build.json`을 읽어 다음 `versionCode`를 정합니다. `versionCode + 1`을 사용하고 후속 전달 이력과 다르면 기록부터 정정하며, 기준 파일을 읽지 못하면 번호를 추정하거나 빌드하지 않습니다. 세부와 JSON 형식은 APK 전달 스킬을 따릅니다.

- APK 빌드·재빌드·Dropbox 업로드는 사용자가 명시적으로 요청했을 때만 수행합니다. 일반 개발·리뷰·검증·푸시·웹 배포에 APK 빌드를 추가하지 않습니다.
- [APK 전달 스킬](.agents/skills/dropbox-apk/SKILL.md)을 따릅니다. 로컬에서 빌드하고 연결된 Dropbox 플러그인으로 전달합니다. 직접 API·별도 업로드 스크립트·환경변수의 Dropbox 자격 증명으로 우회하지 않습니다.
- 사용자가 지정한 기본 폴더는 `/앱/initialsj`입니다. 스킬의 파일명 규칙에 따른 APK와 `latest-build.json`만 전달하며 같은 요청에서 목적지 확인을 반복하지 않습니다. 실제 모호함·이름 충돌은 확인합니다.
- GitHub Actions·공개 릴리스·태그·공유 링크·웹 배포는 APK 전달 요청만으로 추가하지 않습니다. 별도로 요청받았을 때만 수행합니다.
- 성공한 빌드와 필요한 검증을 확인한 뒤 업로드하며, 완료 응답의 실제 경로·크기와 기기 실행 여부를 보고합니다. APK만 전달되고 JSON이 실패했다면 구분해 보고합니다.
