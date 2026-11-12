# 코딩 규칙과 폴더 구조

## 포맷과 이름

GDScript는 [gdformatrc](../gdformatrc)를 기준으로 `gdtoolkit==4.5.0`의 `gdformat`을 사용합니다. 탭 들여쓰기·120자 줄 길이·공백·여러 줄 배열과 사전 표기를 자동으로 맞춥니다. 포맷터의 구문 트리·주석 보존 검사를 켜고, 포맷 변경은 기능 변경과 별도 커밋으로 만듭니다. 엔진 전용 `.tscn`·`.tres`·`.import`는 Godot이 저장한 형식을 유지합니다.

```sh
python3 -m venv build/dev-venv
build/dev-venv/bin/python -m pip install -r tools/requirements-dev.txt
build/dev-venv/bin/gdformat scripts models addons tests tools
build/dev-venv/bin/gdformat --check scripts models addons tests tools
```

파일·함수·멤버는 `snake_case`, 상수는 `UPPER_SNAKE_CASE`, 스크립트를 가리키는 지역 상수는 `RaceState`처럼 역할을 드러내는 이름을 씁니다. 외부 API·셰이더 유니폼·공통 APK JSON 필드는 해당 계약의 이름을 유지합니다. Python은4칸, JavaScript·JSON·YAML은2칸 들여쓰기를 사용하며 편집기 공통 설정은 [.editorconfig](../.editorconfig)에 있습니다.

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
| [scripts/ui/](../scripts/ui/) | HUD·메뉴·로딩·화면 전환·차고 미리보기·전광판 |
| [scripts/input/](../scripts/input/) | 키보드·터치·게임패드 해석·진동 |
| [scripts/platform/](../scripts/platform/) | 앱 버전과 브라우저 셸 연동 |

시작 씬은 [boot.tscn](../scenes/boot.tscn)이며 스플래시 뒤 [race.tscn](../scenes/race.tscn)을 엽니다. 상태 조정자는 [race.gd](../scripts/race/race.gd)입니다. 파일을 옮길 때는 `.uid`를 함께 보존하고 런타임·모델·검사·내보내기 도구·문서의 경로를 함께 갱신합니다. 모델별 형상·재질·출처는 기존 [models/](../models/) 팩 안에서 소유하며 [모델 제작 계약](MODEL_PIPELINE.md)을 따릅니다.

## 헬퍼와 수명

같은 계약을 실제로 공유하는 동작은 소유 영역의 헬퍼로 옮깁니다. 화면 입력은 `RaceInput`, 조명은 `RaceLighting`, 브라우저는 `WebShell`이 담당하고 경기 흐름은 [race.gd](../scripts/race/race.gd)에 남깁니다. 모든 보조 함수를 모으는 `helpers/`·`utils/` 폴더는 만들지 않습니다.

GLB 모델 로더와 연결 계약은 [models/shared/](../models/shared/), 공유 메시·미리 읽기·해제는 [render_resources.gd](../scripts/rendering/render_resources.gd)에 둡니다. 메시의 축·원점·UV, 재질·충돌층·캐시 소유권이 다르면 이름만 비슷하다고 합치지 않습니다. 예를 들어 구조물의 보와 놀이기구의 원통은 서로 다른 길이 축을 사용합니다.

사용하지 않는 `preload`·셰이더 sampler·바인딩을 제거하고, 다른 런타임 참조가 사라진 리소스만 사이드카와 함께 삭제합니다. 자동 탐색 모델 팩, 출처·라이선스, 이전 서비스 워커 해제 파일은 일반적인 문자열 참조 수만 보고 지우지 않습니다.

## 주석·문서·검사

주석은 단위·좌표축·유효 범위·수명·알고리즘을 선택한 이유를 설명합니다. 코드와 같은 내용을 반복하거나 수정 이력·리뷰 결과를 소스에 쌓지 않습니다. 현재 계약은 [아키텍처](ARCHITECTURE.md)·[게임 규칙](GAMEPLAY.md)에 쓰고, 변경 이력은 Git에서 확인합니다. 생성 보고서는 `build/reports/`에 둡니다.

문서에서 정본을 가리킬 때는 실제 파일에 대한 상대 링크를 사용합니다. `verify_repository.py`가 파일·한글 제목 앵커·사이드카·미사용 셰이더 sampler를 확인합니다. 실행 명령과 검증 범위는 [개발 안내](DEVELOPMENT.md#기본-검사)를 따릅니다.
