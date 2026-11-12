# UI 이미지 출처

해안의 채도·방향광·입체 형상을 기준으로 제작합니다. 로딩 이미지는 가상의 흰색·청록 해치백과 맑은 낮의 해안도로를 사용합니다. 메인·차고 배경 위 차량은 주행과 같은 차량 팩토리의 캐시 렌더이며 튜닝샵은 실제 선택 차량을 독립3D 뷰포트에 표시합니다. 코스 카드의 콘셉트 이미지와 실제 게임 캡처는 아래에서 구분합니다.

| 사용 에셋 | 원본·제작 방식 |
| --- | --- |
| [로딩·엔진 스플래시](backgrounds/loading_coast.png) | 생성 원본 `exec-b0e61825-2b5b-4420-b886-d75a239ac6ed.png`. 기존 구도를 참고해 맑은 낮·청록 바다·깨끗한 차량·밝은 하단 여백으로 재생성 |
| [튜닝샵](backgrounds/tuning_bay.png) | 디자인 시안 `exec-3eb29df1-f769-45b1-a4b5-362fd4a52203.png`에서 생성한 배경 원본 `exec-cb9f33a4-843a-48c2-96d1-352dc9734c42.png`. 흰색·청록·노랑 UI의 기준이며 배경에는 차량·문구·버튼을 포함하지 않음 |
| [메인 해안](backgrounds/home_coast.png) | 생성 원본 `exec-83b2a747-ade7-4946-9dca-db44ebbc8894.png` |
| [차고](backgrounds/garage_bay.png) | 생성 원본 `exec-013bcb89-1cda-4f48-ab68-254e386b4aee.png` |
| [후지 코스 카드](courses/fuji.png) | 콘셉트 생성 원본 `exec-8be49d29-fe68-4ee5-94d1-43c803ed3ae1.png` |
| [스피드웨이 코스 카드](courses/speedway.png) | 콘셉트 생성 원본 `exec-80a07cec-f581-4b02-b13d-d7cb3c6984e7.png` |
| [야간 항만·리비에라·협곡 코스 카드](courses/scenery_atlas.png) | 생성형 이미지 `exec-0e0791b7-8d8d-43c8-bf68-5826cc23d485.png`. 후지·스피드웨이 콘셉트 아트를 화풍 참고로 사용. 세 풍경을 AtlasTexture로 분리해 공유하며 차량·문구 없는 코스 일러스트로 통일 |

사용한 생성 PNG 원본은 로컬의 Git 제외 폴더 `generated_images/`에 보존합니다. 배포 사본은 `backgrounds/`·`courses/`에 두고 로고·아이콘은 `branding/`·`controls/`에서 관리합니다. 외부 사진·실존 제조사 로고·원본 아케이드 게임 에셋을 합성하지 않습니다. 제목·버튼·성능 막대·진행 표시는 모바일 가독성을 위해 UI 코드로 별도 렌더링하며 도로·미니맵도 게임이 생성합니다.

## 게임 로고

[initialsj_logo.svg](branding/initialsj_logo.svg)는 [tools/bake_logo.py](../../tools/bake_logo.py)가 번들 Roboto Bold Italic 윤곽선으로 만드는 벡터 워드마크입니다. 글꼴은 Apache-2.0이며 [라이선스](../fonts/Roboto-LICENSE.txt)를 보존합니다. 아이보리·청록 글자와 주황색 사선, 작은 부제를 사용하며 시스템 글꼴에 의존하지 않습니다.

메인·로딩 화면이 같은 SVG를 사용합니다. 제작 도구는 `web/coast-rush-shell.html`의 `<!--logo:start-->` 구간에도 동일한 SVG를 삽입해 엔진 다운로드 전부터 표시합니다. 변경 후 `python3 tools/bake_logo.py`를 실행하고 SVG와 셸을 함께 커밋합니다. 실행에는 fontTools가 필요합니다.



새 로딩·튜닝 배경은 OpenAI 이미지 생성 도구로 제작한16:9 PNG입니다. 실제 제조사·로고·외부 사진을 사용하지 않았습니다. 튜닝 시안은 레이아웃 참고로만 사용하며 버튼·색상 선택·상태·텍스트는 실제 네이티브 컨트롤로 구현합니다.

튜닝샵 제목·부제·브랜드·버튼·상태는 번역 가능한 네이티브 텍스트로 표시합니다. 생성 시안은 색·형상·배치 참고로만 사용하며 UI 문자를 이미지에 굽지 않습니다.
