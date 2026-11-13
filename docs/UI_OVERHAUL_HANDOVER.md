# UI & 2D 스타일라이즈드 비주얼 개편 인수인계서 (Handover)
이 문서는 `experiment/modern-ui-track01` 브랜치에서 진행된 UI 및 비주얼 전면 개편 작업의 초기 계획, 진행 현황, 세부 기술 구현 및 후속 AI 에이전트를 위한 향후 과제(Next Steps)를 정리한 문서입니다.

## 1. 개요 및 배경
- **브랜치명**: `experiment/modern-ui-track01`
- **베이스 커밋**: `origin/main` (`242e183` 기반 최신 리베이스 완료)
- **추진 배경**:
  - 기존 UI의 투박한 사각 버튼 나열 형태와 표준 PBR 3D 렌더링 룩을 2D 애니메/카툰 레이싱 콘셉트(생성형 레퍼런스 4종: 설정, 카운트다운, 주행 HUD, 레이스 결과)에 부합하도록 전면 개편.
  - 사용자 피드백을 반영하여 12회차 감독자(Supervisor) 하네스 체계를 수립하고 점진적으로 비주얼 격차를 좁힘.

## 2. 레퍼런스 원화 이미지 및 상세 계획서 위치
- **상세 12회차 작업 계획서**: [UI_OVERHAUL_PLAN.md](UI_OVERHAUL_PLAN.md)
- **로컬 레퍼런스 콘셉트 원화 이미지 4종 (`generated_images/`)**:
  - `generated_images/concept_hud.jpg`: 슬림 디지털 계기판, 17-LED 세그먼트 RPM 바, 대형 원형 네온 니트로 & 드리프트 버튼, 상단 플로팅 정보 바
  - `generated_images/concept_countdown.jpg`: 오버헤드 메탈 트러스 갠트리 신호등(3구 대형 램프 Red-Yellow-Green), 48눈금 타코미터 펄스 아크 링
  - `generated_images/concept_settings.jpg`: 둥근 다크 글래스 카드, 슬라이딩 네온 토글 스위치(Pill Switch), 3단 세그먼트 셀렉터, 네온 캡슐 DONE 버튼
  - `generated_images/concept_results.jpg`: 골드 1ST PLACE 엠블럼, 다크 글래스 빅토리 카드 상단 네온 라인, 2x2 통계 타일 그리드
  - `generated_images/legacy_settings_screenshot.png`: 개편 전 구형 사각 버튼 방식 캡처 (비교용)

## 2. 초기 계획과 12회차 진행 현황
- **1차 블록: 핵심 비주얼 & UI 전면 개편 (Round 1 ~ 3)**:
  - **Round 1 (`07a3eb0`)**: 설정(Settings) 화면 전면 리뉴얼. 사각 버튼 제거 후 캡슐형 슬라이딩 네온 토글 스위치(`draw_toggle_switch`), 3단 세그먼트 셀렉터(`draw_segmented_selector`), 둥근 다크 글래스 카드 및 네온 DONE 버튼 구현.
  - **Round 2 (`d6dc84c`)**: 카운트다운 오버헤드 메탈 트러스 갠트리 신호등(`draw_gantry`: 3구 램프 Red-Yellow-Green 시퀀셜 점등/글로우) 및 중앙 48눈금 HUD 타코미터 펄스 아크 링 연출.
  - **Round 3 (`953bd45`)**: 차량 2D 카툰/셀 셰이더 적용(`vehicle_body.gdshader`, `vehicle_livery.gdshader`: 2단계 Toon Cel-shading 음영 밴딩, 프레넬 네온 림 라이트 `rim_glow`). 1차 Web WASM 배포.
- **2차 블록: 주행 HUD & 결과창 그래픽 (Round 4 ~ 6)**:
  - **Round 4 (`0218ba4`)**: 주행 HUD 디지털 계기판 17-LED 세그먼트 RPM 바(Green/Yellow/Red 동적 점등), 대형 원형 네온 니트로 & 드리프트 버튼 에너지 링 강화.
  - **Round 5 (`e750004`)**: 레이스 결과 빅토리 카드 네온 하이라이트 라인, 1ST PLACE 골드 엠블럼, 2x2 통계 타일 그리드 및 네온 CONTINUE 버튼 마감.
  - **Round 6 (`967822d`)**: 카운트다운 카메라 하이앵글 글라이드 인 연출(`world_race.gd`: `-forward*14.5, UP*8.2, FOV 78`에서 레이스 출발 시 체이스 캠으로 부드러운 전환). 2차 Web WASM 배포.
- **3차 블록: 인터랙션 & 이펙트 고도화 (Round 7 ~ 9)**:
  - **Round 7 (`e59edc9`)**: 설정 화면 슬라이딩 토글 트랙 내부 네온 글로우, 정밀 놉 코어 및 3단 세그먼트 셀렉터 하단 액티브 인디케이터 바 추가.
  - **Round 8 (`5e7caed`)**: 트랙 노면 아스팔트 및 도로 셰이더(`asphalt.gdshader`)에 2D 애니메 프레넬 림 반사 및 가장자리 네온 앰비언트 라이팅 일체화.
  - **Round 9 (`45324fd`)**: 주행 스피드라인(`speed_blur.gdshader`)에 방사형 네온 스피드라인(`speed_effect`) 구현으로 부스터/고속 주행 질주감 완성. 3차 Web WASM 배포.
- **4차 블록: 전체 통합 & 최종 마감 (Round 10 ~ 12)**:
  - **Round 10 (`4a4b9c4`)**: 일시정지(PAUSED) 모달 상단 네온 라인, RESUME 네온 캡슐 버튼 등 레이스 사이클 전반의 글래스모피즘 테마 일관성 마감.
  - **Round 11 (`76f350e`)**: 모바일/웹 터치 조작 시 액션 버튼 히트박스 완충 마진(18%) 적용(`hit_button`), 터치 입력 반응성 및 60fps 유지 최적화.
  - **Round 12 (`76f350e`)**: 종합 정적 검사, Web WASM 내보내기 검증(`build/site/index.html`) 및 릴리스 검증 통과.

## 3. 핵심 변경 파일 및 기술적 주의사항
- **`scripts/ui/hud.gd`**:
  - 카운트다운 신호등(`draw_gantry`), 타코미터 펄스 링(`draw_countdown`), 17-LED 세그먼트 속도계(`draw_speedometer`), 일시정지 모달(`draw_rect`, `glass_box`), 터치 판정(`hit_button`).
  - **중요**: GDScript 4.5 웹 컴파일러에서 암시적 타입 추론(`:=`) 오류로 크래시가 발생할 수 있으므로, `var pos_num: int = race.race_position()`, `var step_progress: float = ...`와 같이 명시적 정적 타입을 필히 선언해야 합니다.
- **`scripts/ui/hud_menus.gd`**:
  - 설정 화면 모달(`draw_settings`), 슬라이딩 네온 토글 스위치(`draw_toggle_switch`), 3단 세그먼트 셀렉터(`draw_segmented_selector`).
- **`scripts/ui/result_panel.gd`**:
  - 결과창 빅토리 카드, 1ST PLACE 골드 엠블럼, 통계 타일 네온 라인(`draw_tile`).
- **`shaders/vehicle_body.gdshader` / `vehicle_livery.gdshader`**:
  - 2단계 계단식 `light()` 셰이딩 함수, `rim_glow` 프레넬 네온 림 라이트.
- **`shaders/asphalt.gdshader`**:
  - 스타일라이즈드 프레넬 림 반사 및 가장자리 네온 앰비언트 라이팅.
- **`shaders/speed_blur.gdshader`**:
  - 방사형 애니메 스피드라인(`speed_effect`).

## 4. 후속 AI 에이전트 인수인계 과제 (To-Do)
- **1) 다른 코스(트랙 2~5 및 투어) 배경 스타일라이즈드 조명 확장**:
  - 현재 트랙 1(Fuji) 및 기본 아스팔트에 집중 적용된 카툰 림/톤을 Suncoast Speedway, Midnight Harbor, Azure Riviera, Scarlet Gorge 및 Tour 환경 셰이더와 조명에도 확장 적용.
- **2) 차량 외곽선(Outline) 및 리버리 인라인 강화**:
  - 차체 외곽에 굵은 먹선 외곽선(Inverted hull outline mesh 또는 스크린 스페이스 엣지 감지)을 보강하여 2D 애니메 감성을 한층 더 강화할 수 있음.
- **3) 모바일 터치 컨트롤 레이아웃 설정 지원**:
  - 다양한 스마트폰 및 태블릿 화면비에서 사용자가 버튼 크기나 위치(좌우 반전, 크기 조절)를 커스텀할 수 있는 옵션 확장 고려.
- **4) 화면 전환(Transition) 마이크로 인터랙션**:
  - 설정 모달이나 결과창이 나타나고 닫힐 때 부드러운 스케일/알파 페이드 애니메이션 추가 검토.
- **5) main 브랜치 통합 전략 결정**:
  - 기존의 밝은 해안(Bright theme) UI와 새 다크 네온 UI를 사용자 옵션(Theme: Bright / Dark Neon)으로 선택 가능하게 할 것인지, 전면 교체할 것인지 프로젝트 리드와 결정 후 병합.

## 5. 검증 및 빌드 가이드
- **정적 코드 검사**:
  - `python tools/check.py --static`
- **Web WASM 빌드**:
  - `& "C:\Users\user\.godot-tools\win\Godot_v4.5.1-stable_win64_console.exe" --headless --path . --export-release Web build/site/index.html`
- **웹 빌드 검증**:
  - `python tools/verify_web_export.py build/site/index.html`
- **로컬 웹 서버 구동**:
  - `python build/serve.py` (접속: `http://localhost:8080`)
