---
name: dropbox-apk
description: Initial SJ APK를 로컬에서 빌드하고 연결된 Dropbox 플러그인으로 /앱/initialsj에 전달한다. APK 빌드 후 드롭박스 업로드 요청에 사용한다.
---

# Initial SJ APK → Dropbox

## 사용자가 지정한 기본 전달 설정

- 대상 프로젝트는 `obmaz/initialsj`이다.
- 기본 Dropbox 폴더는 `/앱/initialsj`이다.
- APK 이름은 `initialsj-<실제 versionName>-arm64-<빌드한 커밋의 짧은 SHA>.apk`로 한다.
- 같은 이름에서 확장자만 `.json`으로 바꾼 빌드 기록도 같은 폴더에 전달한다.
- 사용자는 이 기본 경로·파일명 규칙·APK와 기록의 전달을 지정했다. 이후 APK 빌드 및 Dropbox 업로드 요청에서는 이 설정을 적용하고 경로 확인을 반복하지 않는다. 사용자가 다른 경로를 명시하면 그 요청을 따른다. 원본이나 목적지가 실제로 모호하거나 이름이 충돌하면 확인한다.
- Dropbox 플러그인만 사용한다. 직접 API·별도 업로드 스크립트·환경변수의 Dropbox 자격 증명으로 우회하지 않는다. 공유 링크는 요청받았을 때만 만든다.

## 로컬 빌드와 검증

1. `AGENTS.md`, 현재 브랜치와 작업 트리를 읽고 원격 HEAD를 확인한다. 동기화를 요청받지 않았다면 작업 트리를 임의로 변경하지 않는다.
2. [Android 안내](../../../docs/ANDROID.md)와 [개발 안내](../../../docs/DEVELOPMENT.md)를 따른다. 엔진은 `./tools/godot`이 검증하는 Godot 4.7.2를 사용한다. 기본은 저장소의 기존 테스트 키로 서명하는 `tools/build_android.sh`이다. 정식 배포용 서명은 명시적으로 요청받았을 때만 사용한다.
3. SDK·템플릿·Java 경로를 확인한다. `JAVA_HOME`은 실제 Java 설치 디렉터리를 가리켜야 한다. `XDG_CONFIG_HOME`을 사용한다면 빌드 스크립트가 쓰는 `$HOME/.config/godot` 설정을 엔진도 읽도록 맞춘다. `XDG_DATA_HOME`을 사용한다면 Android export template도 엔진이 읽는 위치에 있어야 한다.
4. 필요한 저장소 검사와 주행 회귀 검사를 수행한다. 같은 소스에서 이미 통과한 검사는 반복하지 않는다. 검증 실패 시 전달하지 않는다.
5. 새 APK 생성과 빌드 성공을 확인한다. 실패한 빌드 대신 이전 산출물을 전달하지 않는다. `aapt dump badging`으로 실제 버전·패키지·arm64 ABI·권한을 확인하고 `apksigner verify --verbose --print-certs` 및 `zipalign -c -P 16 4`로 서명과 정렬을 확인한다. 기기에서 실행하지 않았다면 그 범위를 명시한다.
6. 전달 폴더의 APK와 JSON 이력을 확인한다. 버전을 갱신할 때 기존 전달본보다 `versionCode`를 낮추지 않는다. Flutter 전용 빌드 번호·서명·JNI 명령을 이 Godot 프로젝트에 적용하지 않는다.

## 업로드

1. 플러그인의 `list_folder`로 `/앱/initialsj`의 존재와 이름 충돌을 확인하고 페이지가 남으면 이어 읽는다. 반환된 namespace 경로는 그대로 재사용한다.
2. APK의 로컬 SHA-256과 Dropbox content hash를 계산한다. JSON에는 실제 버전·빌드 번호·빌드한 커밋·파일명·크기·서명 SHA-256 지문·로컬 해시·검증 범위를 기록한다. 스킬이나 문서만 나중에 커밋했다면 APK를 실제로 빌드한 SHA를 유지한다.
3. `upload_file`에 로컬 APK의 절대 경로를 `source_file`로, 기본 폴더와 규칙에 따른 전체 경로를 `destination_path`로 전달한다. `in_progress`이면 반환된 작업 ID와 권장 간격으로 `check_upload_file_status`를 사용한다. `completed`가 확인된 뒤 JSON을 업로드한다.
4. 이름 충돌 시 덮어쓰기·삭제·다른 이름 재시도를 임의로 수행하지 않는다. 기존 기록을 덮어쓰거나 삭제하지 않는다.
5. 완료 응답의 실제 경로와 크기를 확인하고 보고한다. APK만 성공하고 JSON이 실패했다면 구분해 보고하고 APK를 다시 올리지 않는다. 서버 해시를 받지 않았다면 서버 해시 검증을 주장하지 않는다.
6. 빌드·전달 요청에 GitHub Actions, 공개 릴리스, 태그 또는 웹 배포를 추가하지 않는다.
