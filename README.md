# Initial SJ — Racing Collection

**[게임 선택 화면](https://obmaz.github.io/initialsj/)**

| 버전 | 플레이 | 소스 |
| --- | --- | --- |
| Initial SJ Legacy — 기존 세로 화면 레이싱 | [/initialsj/legacy/](https://obmaz.github.io/initialsj/legacy/) | [`legacy/`](legacy/) |
| Alpine Rush — 새 가로 화면 3D 레이싱 | [/initialsj/new/](https://obmaz.github.io/initialsj/new/) | [`new/`](new/) |

`site/`는 두 게임을 선택하는 정적 첫 화면입니다. 기존 Flutter 소스는 `legacy/`에 보존했습니다.

## 새 게임 실행

Godot에서 [`new/project.godot`](new/project.godot)을 열고 F5를 누릅니다. [조작과 구현 범위](new/README.md)를 확인하세요.

요청 목표 버전은 **Godot 4.7.2**, 현재 실제 개발·웹 내보내기·검증 버전은 **Godot 4.6.3 stable**입니다. 아직 4.7.2에서 검증하지 않았습니다.

```sh
godot --headless --path new --editor --import --quit
godot --headless --path new --script res://tests/race_test.gd
godot --path new
```

## 기존 게임 실행

Flutter SDK를 설치하고 다음을 실행합니다.

```sh
cd legacy
flutter pub get
flutter run
```

## 웹 배포

`main` 푸시 또는 GitHub Actions의 **Deploy Racing Collection to GitHub Pages** 수동 실행으로 두 버전을 함께 배포합니다.

1. Flutter를 검사하고 `/initialsj/legacy/` base href로 빌드합니다.
2. Godot 주행 검사를 실행하고 단일 스레드 Web release를 `/new/`에 내보냅니다.
3. `site/` 첫 화면, 기존 게임, 새 게임을 `build/site/`에 모아 GitHub Pages에 배포합니다.

단일 스레드 Godot Web export를 사용하므로 SharedArrayBuffer나 COOP/COEP 헤더가 필요 없습니다. 실행에는 WebGL 2 지원 브라우저가 필요합니다. 기존 Flutter 루트 서비스 워커는 정리용 워커로 교체해 이전 캐시가 선택 화면을 가리지 않도록 합니다. 두 게임 모두 새 서비스 워커를 등록하지 않습니다.

로컬 웹 내보내기는 해당 Godot 버전의 export templates 설치 후 실행합니다.

```sh
mkdir -p build/site/new
godot --headless --path new --export-release Web ../build/site/new/index.html
```
