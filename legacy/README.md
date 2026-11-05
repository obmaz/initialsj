# Initial SJ — Legacy

## Play on Mobile

모바일에서 아래 GitHub Pages 주소로 접속하면 바로 게임을 실행할 수 있습니다.

https://obmaz.github.io/initialsj/legacy/

주의: 이 프로젝트는 모바일 세로 화면 기준으로 맞춰져 있어서 PC에서 접속하면 화면 레이아웃이 깨질 수 있습니다.

Flutter와 Flame으로 만든 세로 화면 레이싱 게임 프로젝트입니다. 차량 선택, 주행, 결과 화면, 로컬 프로필 저장을 포함한 아케이드 스타일 루프를 구현하고 있습니다.

## Features

- 세로 화면 기준 플레이
- 차량 선택 및 구매 시스템
- 주행 중 HUD, 조이스틱, 니트로 버튼
- 결과 화면과 최고 점수/코인 반영
- `SharedPreferences` 기반 로컬 프로필 저장
- GitHub Pages용 웹 배포 워크플로 포함

## Tech Stack

- Flutter
- Flame
- Provider
- GoRouter
- Shared Preferences

## Project Structure

```text
lib/
├── app/          # 앱 부트스트랩, 라우터, 테마
│   ├── router/
│   └── theme/
├── core/         # 공통 로직 및 서비스
│   ├── constants/
│   ├── platform/
│   └── services/
├── features/     # 각 화면별 기능
│   ├── gameplay/
│   ├── garage/
│   ├── results/
│   └── title/
├── game/         # Flame 게임 엔진 및 요소
│   ├── engine/
│   ├── entities/
│   ├── hud/
│   └── world/
└── shared/       # 공용 상태, 모델, 위젯
    ├── models/
    ├── state/
    └── widgets/

assets/
├── audio/
├── fonts/
├── images/
│   ├── backgrounds/
│   ├── effects/
│   ├── environment/
│   ├── overlays/
│   ├── tiles/
│   ├── ui/
│   └── vehicles/
└── stages/       # 스테이지 텍스트 데이터
```

## Requirements

- Flutter SDK: 프로젝트 `pubspec.yaml` 기준 `^3.11.3`
- Dart SDK: Flutter 버전에 포함된 대응 버전

## Getting Started

```bash
flutter pub get
flutter run
```

릴리스 웹 빌드:

```bash
flutter build web --release
```

Android APK 빌드:

```bash
flutter build apk --release
```

iOS 릴리스 빌드:

```bash
flutter build ios --release
```
