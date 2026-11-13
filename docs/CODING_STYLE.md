# 코딩 규칙과 폴더 구조

## 포맷과 이름

GDScript는 [gdformatrc](../gdformatrc)를 기준으로 `gdtoolkit==4.5.0`의 `gdformat`을 사용합니다. 탭 들여쓰기·120자 줄 길이·공백·여러 줄 배열과 사전 표기를 자동으로 맞춥니다. 포맷터의 구문 트리·주석 보존 검사를 켜고, 포맷 변경은 기능 변경과 별도 커밋으로 만듭니다. 엔진 전용 `.tscn`·`.tres`·`.import`는 Godot이 저장한 형식을 유지합니다.

GDScript와 Python의 줄 길이는 120자를 목표로 합니다. 긴 조건·주석은 의미 단위로 나누고 생성용 문자열을 분리할 때는 연결한 값이 같은지 확인합니다. 포맷터가 분리하지 않는 번역 키·리소스 경로·생성용 데이터 리터럴은 값과 연결 관계를 보존하기 위해 초과를 허용합니다.

```sh
python3 -m venv build/dev-venv
build/dev-venv/bin/python -m pip install -r tools/requirements-dev.txt
build/dev-venv/bin/gdformat scripts models addons tests tools
build/dev-venv/bin/gdformat --check scripts models addons tests tools
```

파일·함수·멤버는 `snake_case`, 상수는 `UPPER_SNAKE_CASE`, 스크립트를 가리키는 지역 상수는 `RaceState`처럼 역할을 드러내는 이름을 씁니다. 외부 API·셰이더 유니폼·공통 APK JSON 필드는 해당 계약의 이름을 유지합니다. Python은 4칸, JavaScript·JSON·YAML은 2칸 들여쓰기를 사용하며 편집기 공통 설정은 [.editorconfig](../.editorconfig)에 있습니다.

직접 관리하는 UI 이미지도 `snake_case`로 이름을 붙이고 기능별 폴더로 나눕니다. `tuning_theme.gd`·`loading_overlay.gd`처럼 파일명에는 실제 역할을 적습니다. 글꼴·외부 에셋의 원래 이름과 모델 팩의 기존 ID는 출처·연결 계약을 따릅니다.

같은 화면에 여러 상태가 있으면 `preview_car`·`saved_customization`·`draft_customization`처럼 대상과 수명을 구분합니다. 계산 단위가 모호하면 `track_length_m`·`last_sample_usec`·`sample_elapsed_seconds`처럼 단위를 표시하고, 상태 플래그는 `is_comparing`·`show_illustration`처럼 읽히게 짓습니다. 변수명 정리와 저장 파일의 키·모델 노드 이름·직렬화된 속성 변경을 섞지 않습니다.

스크립트 참조를 재대입하지 않으면 지역 `const WorldAssets = preload(...)`처럼 선언합니다. 조건 이름은 실제 판단을 드러냅니다. 예를 들어 낮의 비·저녁까지 포함하는 전조등 조건은 `needs_headlights`로 표현하고, 모든 불리언에 `is_`를 기계적으로 붙이지 않습니다. 도·라디안이 함께 등장하는 경계는 `angle_deg`·`angle_rad`처럼 단위를 명시합니다.

설정·저장 파일에서 읽은 원시 값은 `Variant`로 받고 타입과 허용값을 확인한 뒤 상태에 반영합니다. 타입 표기를 늘리기 위해 외부 값을 바로 `String`으로 강제하지 않습니다. 브라우저 객체처럼 실제 타입을 아는 경계는 `JavaScriptObject`로 표현하고, ID로 조회한 노드는 유효성과 기대 타입을 함께 확인합니다.

관측 목록에는 이미 해제된 노드가 남을 수 있습니다. 이런 목록에서 꺼낸 값은 `Variant`로 받고 `is_instance_valid`를 통과한 뒤 `Node` 변수에 대입합니다. 구체 타입으로 먼저 대입하면 유효성 검사 전에 Godot 오류가 발생할 수 있습니다.

공개 헬퍼는 인자·반환형을 선언하고, 이미 구체형을 아는 상태·배열은 그 형식을 사용합니다. 코스·시각 어댑터가 서로 다른 스크립트를 받을 때는 `Node3D`처럼 공통 계약을 사용합니다. 타입을 억지로 바꾸기 위해 순환 `preload`나 모든 것을 담는 전역 등록표를 만들지 않습니다.

## 런타임 폴더

| 폴더 | 소유하는 책임 |
| --- | --- |
| [scripts/race/](../scripts/race/) | 경기 상태·주행 조정·상대 차량·순위·복구·니트로 |
| [scripts/physics/](../scripts/physics/) | 공통 실제 차체·충돌체·접지·충돌·조향 저항 |
| [scripts/track/](../scripts/track/) | 코스 프로필·거리 계측·기믹·노면·투어 분기 구간 |
| [scripts/environment/](../scripts/environment/) | 지역 메타정보·풍경·배치·날씨·구조물·광고·시각 모델 어댑터 |
| [scripts/vehicles/](../scripts/vehicles/) | 차량 시각 어댑터·카탈로그·생성 |
| [scripts/rendering/](../scripts/rendering/) | 공용 렌더 자원·화질·조명 |
| [scripts/effects/](../scripts/effects/) | 충돌·착지·축하·물보라·타이어 자국 |
| [scripts/audio/](../scripts/audio/) | 차량별 음원과 경기 효과음 재생 |
| [scripts/ui/](../scripts/ui/) | HUD·메뉴·차고 미리보기·전광판 |
| [scripts/ui/loading/](../scripts/ui/loading/) | 시작 스플래시·로딩 표시·화면 전환 |
| [scripts/ui/tuning/](../scripts/ui/tuning/) | 튜닝샵·전용 테마·미리보기 조작 |
| [scripts/input/](../scripts/input/) | 키보드·터치·게임패드 해석·진동 |
| [scripts/platform/](../scripts/platform/) | 앱 버전과 브라우저 셸 연동 |

시작 씬은 [boot.tscn](../scenes/boot.tscn)이며 스플래시 뒤 [race.tscn](../scenes/race.tscn)을 엽니다. 상태 조정자는 [race.gd](../scripts/race/race.gd)입니다. 파일을 옮길 때는 `.uid`를 함께 보존하고 런타임·모델·검사·내보내기 도구·문서의 경로를 함께 갱신합니다. 모델별 형상·재질·출처는 기존 [models/](../models/) 팩 안에서 소유하며 [모델 제작 계약](MODEL_PIPELINE.md)을 따릅니다.

UI 이미지의 정본은 `assets/ui/` 아래 `branding/`(아이콘·로고), `backgrounds/`(메인·차고·로딩·튜닝 배경), `courses/`(코스 카드·아틀라스), `controls/`(터치 조작 아이콘)에 둡니다. [이미지 출처](../assets/ui/GENERATED_ART.md)는 공통 목록을 유지합니다. 이미지를 옮길 때 `.import`도 함께 옮겨 UID를 보존하고 Godot 임포트로 캐시 경로를 갱신합니다.

## 헬퍼와 수명

같은 계약을 실제로 공유하는 동작은 소유 영역의 헬퍼로 옮깁니다. 화면 입력은 `RaceInput`, 조명은 `RaceLighting`, 브라우저는 `WebShell`이 담당하고 경기 흐름은 [race.gd](../scripts/race/race.gd)에 남깁니다. 모든 보조 함수를 모으는 `helpers/`·`utils/` 폴더는 만들지 않습니다.

GLB 모델 로더와 연결 계약은 [models/shared/](../models/shared/), 공유 메시·미리 읽기·해제는 [render_resources.gd](../scripts/rendering/render_resources.gd)에 둡니다. 메시의 축·원점·UV, 재질·충돌층·캐시 소유권이 다르면 이름만 비슷하다고 합치지 않습니다. 예를 들어 구조물의 보와 놀이기구의 원통은 서로 다른 길이 축을 사용합니다.

사용하지 않는 `preload`·셰이더 sampler·바인딩을 제거하고, 다른 런타임 참조가 사라진 리소스만 사이드카와 함께 삭제합니다. 자동 탐색 모델 팩, 출처·라이선스, 이전 서비스 워커 해제 파일은 일반적인 문자열 참조 수만 보고 지우지 않습니다.

스크립트 상수는 `class_name` 없이도 스크립트 리소스나 인스턴스를 통해 외부에서 접근할 수 있습니다. 선언 파일의 참조 횟수와 함께 다른 스크립트·씬·메타데이터의 접근도 확인합니다. 예를 들어 `hud.AppVersion`은 메뉴 조립기가 사용하는 공개 연결점입니다.

## 주석·문서·검사

주석은 단위·좌표축·유효 범위·수명·알고리즘을 선택한 이유를 설명합니다. 코드와 같은 내용을 반복하거나 수정 이력·리뷰 결과를 소스에 쌓지 않습니다. 현재 계약은 [아키텍처](ARCHITECTURE.md)·[게임 규칙](GAMEPLAY.md)에 쓰고, 변경 이력은 Git에서 확인합니다. 생성 보고서는 `build/reports/`에 둡니다.

문서에서 정본을 가리킬 때는 실제 파일에 대한 상대 링크를 사용합니다. `verify_repository.py`가 파일·한글 제목 앵커·사이드카·미사용 셰이더 sampler를 확인합니다. 실행 명령과 검증 범위는 [개발 안내](DEVELOPMENT.md#기본-검사)를 따릅니다.
