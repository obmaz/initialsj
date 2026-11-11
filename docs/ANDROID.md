# Android APK

웹과 같은 Godot 프로젝트·주행 코드를 사용하며 [Android 내보내기 프리셋](../export_presets.cfg)이 플랫폼 설정을 담당합니다. 버전 번호와 전달 절차는 [APK 전달 스킬](../.agents/skills/dropbox-apk/SKILL.md) 및 [빌드 기록 형식](apk-build-record.md)이 정본입니다.

## 빌드와 전달

APK는 사용자가 명시적으로 요청한 경우에만 로컬에서 빌드합니다. 먼저 Dropbox 플러그인으로 `/앱/initialsj/latest-build.json`을 읽고 다음 번호를 프리셋에 적용합니다. 직접 API·토큰·별도 업로드 스크립트는 사용하지 않습니다.

```sh
python3 tools/optimize_models.py --check
python3 tools/prepare_apk_version.py --project initialsj \
  --latest build/reports/latest-build.json --preset export_presets.cfg
tools/build_android.sh
```

기본 결과는 `build/android/initialsj-debug.apk`입니다. 실제 APK의 버전·서명·패키지·ABI·권한·정렬을 검사하고, 연결된 Dropbox 플러그인으로 `/앱/initialsj/initialsj-<versionName>.apk`를 전달합니다. APK 업로드 완료 후 같은 폴더의 `latest-build.json`만 갱신합니다. 빌드별 JSON은 추가하지 않습니다.

## 필요한 환경

- 고정 엔진은 Godot4.7.2이며 `./tools/godot`으로 실행합니다. `./tools/setup_env.sh --templates android`로 엔진·Android 템플릿을 준비합니다.
- Android SDK 플랫폼35·빌드 도구35.0.1, JDK17 이상이 필요합니다. `ANDROID_HOME` 또는 `ANDROID_SDK_ROOT`로 SDK 경로를 지정합니다.
- SDK가 없으면 빌드 스크립트가 `ANDROID_ACCEPT_LICENSES=1`일 때 설치합니다. 이 설정은 Google SDK 라이선스 동의를 의미합니다.
- 빌드 스크립트는 `$HOME/.config/godot`에 SDK·JDK·디버그 키 설정을 기록합니다. `XDG_CONFIG_HOME`을 따로 사용하면 엔진이 같은 설정을 읽도록 맞춥니다. `XDG_DATA_HOME`도 실제 템플릿 위치와 일치시킵니다.

USB 디버깅을 켠 기기에 `adb install -r build/android/initialsj-debug.apk`로 설치하거나 파일을 복사해 설치합니다.

## 앱 설정

| 항목 | 값 |
| --- | --- |
| 패키지 | `io.github.obmaz.initialsj` |
| 이름·아이콘 | Initial SJ Coast Rush, `assets/android/`, `tools/bake_android_icons.py` |
| CPU | `arm64-v8a` |
| 렌더러 | GL Compatibility, AUTO 화질 |
| 텍스처 | ETC2/ASTC 모바일 형식 |
| 화면 | 가로·몰입 모드 |
| 권한 | 충돌·착지·부스터 진동용 `VIBRATE` |
| 버전 | Dropbox 기록에서 정한 Android 프리셋의 이름·번호. 내보내기 플러그인이 로딩·메인·설정 표시값에도 적용 |

## 공통 디버그 서명

`tools/android-test.keystore`는 `obmaz/commuzip`의 `android/app/debug-keystore.jks`와 동일한 공개 시험용 키입니다. 별칭은 `androiddebugkey`, 키스토어·키 비밀번호는 `android`입니다. 프리셋·편집기·빌드 스크립트에서 같은 키를 사용하며 환경마다 새로 생성하지 않습니다.

인증서 SHA-256은 `5870487504e72ca08671d3229ade28b3136174235309f39afe17d7bee48f02ba`입니다. 다른 서명의 설치본을 이 APK로 덮어쓸 수는 없습니다. 서명이 다르면 기존 앱을 삭제하고 다시 설치해야 하므로 먼저 저장 데이터를 보존합니다.

## 정식 서명

스토어용 APK·App Bundle에는 별도의 비공개 키를 사용합니다. 키를 한 번 만들고 저장소 밖에 보관합니다. 정식 빌드는 명시적으로 요청받았을 때만 수행합니다.

```sh
keytool -genkeypair -v -keystore ~/initialsj-release.keystore -alias initialsj -keyalg RSA -keysize 2048 -validity 10000
INITIALSJ_KEYSTORE=~/initialsj-release.keystore INITIALSJ_KEY_ALIAS=initialsj INITIALSJ_KEY_PASSWORD=... tools/build_android.sh release
```

키를 잃으면 같은 앱 ID로 업데이트할 수 없습니다. 키스토어·비밀번호는 소스나 Dropbox 전달 폴더에 넣지 않습니다.

## 검증 범위

로컬 빌드는 APK 생성·서명·정렬·manifest 검사를 수행합니다. 이 결과와 기기 실행 검증은 구분합니다. 실제 기기에서는 터치·뒤로가기·진동·오디오·성능을 별도로 확인하고, 완료 보고에 기기 실행 여부를 명시합니다. 설치 안내·브라우저 전체화면·Web Audio 브리지는 웹 전용입니다.
