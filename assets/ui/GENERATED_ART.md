# UI 이미지 출처

해안의 채도·방향광·입체 형상을 기준으로 제작합니다. 로딩 이미지는 가상의 흰색·청록 해치백과 맑은 낮의 해안도로를 사용합니다. 메인·차고 배경 위 차량은 주행과 같은 차량 팩토리의 캐시 렌더이며 튜닝샵은 실제 선택 차량을 독립3D 뷰포트에 표시합니다. 코스 카드의 콘셉트 이미지와 실제 게임 캡처는 아래에서 구분합니다.

| 사용 에셋 | 원본·제작 방식 |
| --- | --- |
| [로딩·엔진 스플래시](../../art_sources/ui/coastal/retired/loading_coast.png) | 생성 원본 `exec-b0e61825-2b5b-4420-b886-d75a239ac6ed.png`. 기존 구도를 참고해 맑은 낮·청록 바다·깨끗한 차량·밝은 하단 여백으로 재생성 |
| [튜닝샵](backgrounds/tuning_bay.png) | 디자인 시안 `exec-3eb29df1-f769-45b1-a4b5-362fd4a52203.png`에서 생성한 배경 원본 `exec-cb9f33a4-843a-48c2-96d1-352dc9734c42.png`. 흰색·청록·노랑 UI의 기준이며 배경에는 차량·문구·버튼을 포함하지 않음 |
| [메인 해안](../../art_sources/ui/coastal/retired/home_coast.png) | 생성 원본 `exec-83b2a747-ade7-4946-9dca-db44ebbc8894.png` |
| [차량 선택 배경](backgrounds/tuning_bay.png) | 밝은 튜닝샵과 같은 생성형 원본을 공유. 차량은 실제 선택 차량의 캐시3D 렌더 |
| [트랙·투어 카드](courses/menu_scenery.png) | 생성 원본 `exec-b936d9c1-ce5d-48ee-8c61-76c2615c76b0.png`.3열×2행의1536×1024 아틀라스이며6장의508×508 안쪽 영역을 `.tres`로 공유 |
| [제목판](../../art_sources/ui/coastal/retired/menu_header.png) | 시안 `exec-e0301a4c-17cf-4796-91cb-cbdc9d38377e.png`의 `(144,24)–(733,101)` 빈 장식판을 추출. 글자 없음 |
| [주요 버튼](../../art_sources/ui/coastal/retired/menu_primary.png) | 같은 시안의 `(714,1214)–(1155,1310)` 빈 노란 버튼을 추출. 실제 버튼 이름은 코드로 표시 |

사용한 생성 PNG 원본은 로컬의 Git 제외 폴더 `generated_images/`에 보존합니다. 배포 사본은 `backgrounds/`·`courses/`에 두고 로고·아이콘은 `branding/`·`controls/`에서 관리합니다. 외부 사진·실존 제조사 로고·원본 아케이드 게임 에셋을 합성하지 않습니다. 제목·버튼·성능 막대·진행 표시는 모바일 가독성을 위해 UI 코드로 별도 렌더링하며 코스 미니맵은 실제 주행 프로필에서 그립니다.

## 게임 로고

[initialsj_logo.svg](../../art_sources/ui/coastal/retired/initialsj_logo.svg)는 [tools/bake_logo.py](../../tools/bake_logo.py)가 번들 Roboto Bold Italic 윤곽선으로 만드는 벡터 워드마크입니다. 글꼴은 Apache-2.0이며 [라이선스](../fonts/Roboto-LICENSE.txt)를 보존합니다. 아이보리·청록 글자와 주황색 사선, 작은 부제를 사용하며 시스템 글꼴에 의존하지 않습니다.

시작·홈의 제품명은 실제 번역 가능한 문자로 표시하며 SVG는 웹 시작 셸의 원본으로 보존합니다. 제작 도구는 `web/coast-rush-shell.html`의 `<!--logo:start-->` 구간에도 동일한 SVG를 삽입해 엔진 다운로드 전부터 표시합니다. 변경 후 `python3 tools/bake_logo.py`를 실행하고 SVG와 셸을 함께 커밋합니다. 실행에는 fontTools가 필요합니다.



새 로딩·튜닝 배경은 OpenAI 이미지 생성 도구로 제작한16:9 PNG입니다. 실제 제조사·로고·외부 사진을 사용하지 않았습니다. 튜닝 시안은 레이아웃 참고로만 사용하며 버튼·색상 선택·상태·텍스트는 실제 네이티브 컨트롤로 구현합니다.

튜닝샵 제목·부제·브랜드·버튼·상태는 번역 가능한 네이티브 텍스트로 표시합니다. 생성 시안은 색·형상·배치 참고로만 사용하며 UI 문자를 이미지에 굽지 않습니다.


## 밝은 메뉴 공통 기준

2026-11-12 OpenAI 이미지 생성 도구로 트랙 선택·차량 선택의 두 화면 시안을 제작했습니다. 기존 밝은 튜닝 배경을 참고해 아이보리·남색·청록·노랑·코랄로 통일했습니다. 시안과 실제 화면은 [UI 기준](../../docs/UI_DESIGN.md)에 따라 모바일 비율·번역·터치 영역을 비교합니다. 원본에는 문자가 없으며 차량 카드에도 실제 게임 차량을 사용합니다. 대체된 옛3장 코스 PNG와 어두운 차고 배포 사본은 참조를 제거하고 로컬 원본 보관 폴더에 보존했습니다.

HUD·카운트다운·설정·결과는 새 [네온 기준 원화](../../art_sources/ui/neon/README.md)에 맞춰 2D 벡터 장식과 실제 텍스트로 구성합니다. 대체된 카운트다운 링 PNG·캐시는 실행 경로와 테스트에서 제거했습니다. 원화는 디자인 원본으로 보존하며 내보내기에는 포함하지 않습니다.

## 통이미지 기반 시작 전 화면

현재 시작·홈·트랙·차량·설정은 [공통 생성 원화](../../art_sources/ui/coastal/README.md)를 사용합니다. 마스터는 `exec-336625bf-e3bb-4146-8d9c-f736d7b390bd.png`, 환경판은 `exec-3febe3e1-c23c-42a2-a9bc-aecf18d875b4.png`입니다. 원본·재단 좌표·해시는 [layout.json](../../art_sources/ui/coastal/layout.json)에 보존하고 [bake_pre_race_art.py](../../tools/bake_pre_race_art.py)가 `pre_race/` 통이미지5종과 부품4종을 생성합니다. 원본에는 글자·차량이 없으며 실제 UI 문자·차량은 오버레이합니다. 금속 테두리·질감을 코드로 다시 그리지 않습니다. 이전 표의 메뉴 배경·컨트롤은 대체된 자산의 출처이며 현재 사용 여부는 실행 참조를 따릅니다.
