# 시작 전 해안 UI 원화

[master.png](master.png)는 OpenAI 이미지 생성 도구로 만든 글자·차량 없는 공통 원화입니다.
원본은 `/workspace/generated_images/exec-336625bf-e3bb-4146-8d9c-f736d7b390bd.png`에 보존합니다.
[backdrop.png](backdrop.png)는 같은 원화를 참조해 UI를 제거한 환경판이며 생성 원본은
`exec-3febe3e1-c23c-42a2-a9bc-aecf18d875b4.png`입니다.

[재단·배치·해시 정본](layout.json)은 [베이크 도구](../../../tools/bake_pre_race_art.py)가 관리합니다.
실행 전 Pillow를 설치하고 `python3 tools/bake_pre_race_art.py`로 재생성합니다.
도구는 원본을 보존하고 원화의 실제 프레임 픽셀을 잘라 모서리 밖만 알파로 제거합니다.
프레임의 모서리·금속·반사·질감을 다시 그리지 않습니다. 배포 폴더는
[assets/ui/pre_race/](../../../assets/ui/pre_race/)입니다.

시작·홈(모드 선택)·코스·차량·설정의 1280×720 통이미지가 실제 제품 배경이자 화면별 정본입니다.
원화 구도를 바꾸어 모드를 추가하지 않고 현재 입력 Rect로 재배치합니다. 차량 선택 환경판은 전시대를
실제 차량 쪽에 가깝게 두도록 좌우 반전합니다. 글자·실제 차량·성능·선택·설정 값은 런타임에 얹습니다.
Android와 Web의 설정 푸터 수가 달라 해당 버튼은 같은 재단 이미지로 실행 시 그립니다.
공통 버튼·헤더·패널도 같은 조각으로 바꿔 기존 보조 메뉴가 같은 계열을 쓰게 합니다.

원본 폴더는 Godot 임포트·배포에서 제외합니다. 실제 화면 캡처·역할별 작업 기록·최대5회 검증 기록은
`build/reports/pre-race-art/`에 둡니다. 계획은 [개발 계획](../../../docs/PRE_RACE_ART_PLAN.md)을 따릅니다.
